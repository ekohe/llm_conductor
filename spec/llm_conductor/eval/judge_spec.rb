# frozen_string_literal: true

require_relative 'support'

RSpec.describe LlmConductor::Eval::Judge do
  let(:spec) { EvalSpecSupport::SampleSpec.new }
  let(:store) { LlmConductor::Eval::Store::InMemory.new }
  let(:logger) { Logger.new(File::NULL) }
  let(:result) do
    LlmConductor::Eval::Result.new(input_id: 7, input_label: 'Acme', model: 'gpt-4o-mini',
                                   vendor: :openai, status: 'ok')
  end
  let(:judge) do
    described_class.new(spec:, store:, run_id: 'r1', logger:,
                        judge_model: 'llama-3.3-70b-versatile', judge_vendor: :groq)
  end

  before { store.write_parsed('r1', 7, 'gpt-4o-mini', { 'score' => 88 }) }

  it 'parses a verdict with dimensions clamped to 0-100' do
    allow(LlmConductor).to receive(:generate)
      .and_return(build_response(output: judge_json(quality_score: 85, accuracy: 80, clarity: 90)))
    verdict = judge.judge(model_result: result, input_data: { text: 'x' })
    expect(verdict.quality_score).to eq(85)
    expect(verdict.dimensions).to eq('accuracy' => 80, 'clarity' => 90)
    expect(verdict.judge_model).to eq('llama-3.3-70b-versatile')
  end

  it 'includes the candidate parsed output in the prompt' do
    allow(LlmConductor).to receive(:generate).and_return(build_response(output: judge_json))
    judge.judge(model_result: result, input_data: { text: 'x' })
    expect(LlmConductor).to have_received(:generate) do |args|
      expect(args[:prompt]).to include('"score": 88')
      expect(args[:vendor]).to eq(:groq)
    end
  end

  it 'falls back to raw output when the candidate failed to parse' do
    store_only_raw = LlmConductor::Eval::Store::InMemory.new
    store_only_raw.write_raw('r1', 7, 'gpt-4o-mini', 'RAW broken text')
    j = described_class.new(spec:, store: store_only_raw, run_id: 'r1', logger:)
    allow(LlmConductor).to receive(:generate).and_return(build_response(output: judge_json))
    j.judge(model_result: result, input_data: { text: 'x' })
    expect(LlmConductor).to have_received(:generate) do |args|
      expect(args[:prompt]).to include('PARSE FAILED. RAW OUTPUT:')
      expect(args[:prompt]).to include('RAW broken text')
    end
  end

  it 'retries with exponential backoff on a 429 then succeeds' do
    allow(judge).to receive(:sleep)
    responses = [build_response(output: '', error: 'HTTP 429 rate limit'),
                 build_response(output: '', error: 'rate limit exceeded'),
                 build_response(output: judge_json(quality_score: 70))]
    allow(LlmConductor).to receive(:generate).and_return(*responses)

    verdict = judge.judge(model_result: result, input_data: { text: 'x' })

    expect(verdict.quality_score).to eq(70)
    expect(judge).to have_received(:sleep).with(20).ordered
    expect(judge).to have_received(:sleep).with(40).ordered
    expect(LlmConductor).to have_received(:generate).exactly(3).times
  end

  it 'returns a failure verdict (score 0) when judge output is unparseable' do
    allow(LlmConductor).to receive(:generate).and_return(build_response(output: 'not json'))
    verdict = judge.judge(model_result: result, input_data: { text: 'x' })
    expect(verdict.quality_score).to eq(0)
    expect(verdict.judge_error).to match(/not valid JSON/)
  end

  describe '.borderline?' do
    it 'flags 50-70 inclusive' do
      expect(described_class.borderline?(50)).to be(true)
      expect(described_class.borderline?(70)).to be(true)
      expect(described_class.borderline?(71)).to be(false)
      expect(described_class.borderline?(nil)).to be(false)
    end
  end
end
