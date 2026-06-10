# frozen_string_literal: true

require_relative 'support'

RSpec.describe 'LlmConductor::Eval end-to-end', :with_test_config do
  let(:spec) { EvalSpecSupport::SampleSpec.new }
  let(:store) { LlmConductor::Eval::Store::InMemory.new }
  let(:logger) { Logger.new(File::NULL) }
  let(:inputs) { [{ id: 1, name: 'Acme', text: 'a' }, { id: 2, name: 'Beta', text: 'b' }] }
  let(:models) do
    [{ model: 'gpt-4o-mini', vendor: :openai }, { model: 'gemini-2.5-flash', vendor: :gemini }]
  end

  # Dispatch generate: judge calls pass prompt:, candidates pass type:/data:.
  before do
    allow(LlmConductor).to receive(:generate) do |args|
      if args[:prompt]
        build_response(output: judge_json(quality_score: 82))
      elsif args[:model] == 'gpt-4o-mini'
        build_response(output: candidate_json(score: 90, recommendation: 'YES'))
      else
        build_response(output: candidate_json(score: 40, recommendation: 'NO'))
      end
    end
  end

  def run!
    LlmConductor::Eval.run(spec:, inputs:, models:, store:, logger:,
                           judge: { model: 'judge-x', vendor: :groq }, run_id: 'run_test')
  end

  it 'produces one row per (input, model) pair' do
    report = run!
    expect(report.rows.size).to eq(4)
  end

  it 'writes a resumable manifest after the run' do
    run!
    manifest = store.read_manifest('run_test')
    expect(manifest['rows'].size).to eq(4)
    expect(manifest['judge_model']).to eq('judge-x')
    expect(manifest['finished_at']).not_to be_nil
  end

  it 'persists input data for self-contained re-judging' do
    run!
    expect(store.read_input_data('run_test', 1)).to eq('text' => 'a')
  end

  it 'flags bucket disagreement (models give different recommendations)' do
    report = run!
    expect(report.needs_review.map { |r| r[:input_id] }.uniq).to contain_exactly(1, 2)
    expect(report.needs_review.first[:reasons].first).to match(/buckets_disagree/)
  end

  describe '.report_only' do
    it 'rebuilds an identical report from the manifest with no LLM calls' do
      run!
      RSpec::Mocks.space.proxy_for(LlmConductor).reset
      allow(LlmConductor).to receive(:generate).and_raise('should not be called')

      report = LlmConductor::Eval.report_only(run_id: 'run_test', spec:, store:)
      expect(report.rows.size).to eq(4)
      expect(report.summary.map { |s| s[:model] }).to contain_exactly('gpt-4o-mini', 'gemini-2.5-flash')
    end
  end

  describe '.judge_only' do
    it 're-judges stored outputs without recalling candidate models' do
      run!
      candidate_calls = 0
      allow(LlmConductor).to receive(:generate) do |args|
        raise 'candidate model recalled!' unless args[:prompt]

        candidate_calls += 1
        build_response(output: judge_json(quality_score: 55))
      end

      report = LlmConductor::Eval.judge_only(run_id: 'run_test', spec:, store:, logger:,
                                             judge: { model: 'judge-y', vendor: :groq })
      expect(report.rows.map { |r| r[:judge_verdict].quality_score }).to all(eq(55))
      expect(store.read_manifest('run_test')['judge_model']).to eq('judge-y')
    end
  end

  it 'warns when the judge model also appears in the candidate list' do
    warned = []
    chatty = Logger.new(File::NULL)
    allow(chatty).to receive(:warn) { |msg| warned << msg }
    LlmConductor::Eval.run(spec:, inputs:, models:, store:, logger: chatty,
                           judge: { model: 'gpt-4o-mini', vendor: :openai }, run_id: 'run_self')
    expect(warned.join).to match(/self_judge/)
  end
end
