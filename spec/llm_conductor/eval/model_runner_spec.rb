# frozen_string_literal: true

require_relative 'support'

RSpec.describe LlmConductor::Eval::ModelRunner do
  let(:spec) { EvalSpecSupport::SampleSpec.new }
  let(:store) { LlmConductor::Eval::Store::InMemory.new }
  let(:logger) { Logger.new(File::NULL) }
  let(:input) { { id: 7, name: 'Acme', text: 'about acme' } }

  def run_with(response)
    allow(LlmConductor).to receive(:generate).and_return(response)
    described_class.new(input, model: 'gpt-4o-mini', vendor: :openai, spec:,
                               store:, run_id: 'r1', logger:).run
  end

  it 'passes type + data for a spec with a prompt_type' do
    allow(LlmConductor).to receive(:generate)
      .and_return(build_response(output: candidate_json))
    described_class.new(input, model: 'gpt-4o-mini', vendor: :openai, spec:,
                               store:, run_id: 'r1', logger:).run
    expect(LlmConductor).to have_received(:generate)
      .with(model: 'gpt-4o-mini', vendor: :openai, type: :analyze_content, data: { text: 'about acme' })
  end

  context 'on a successful, parseable response' do
    let(:result) { run_with(build_response(output: candidate_json(score: 88, recommendation: 'YES'))) }

    it 'captures status, score, bucket, tokens and cost' do
      expect(result.status).to eq('ok')
      expect(result.parsed_score).to eq(88)
      expect(result.parsed_bucket).to eq('YES')
      expect(result.total_tokens).to eq(30)
      expect(result.input_label).to eq('Acme')
    end

    it 'stores parsed output retrievable by the judge' do
      result
      expect(store.read_parsed('r1', 7, 'gpt-4o-mini')).to include('score' => 88)
    end

    it 'records extra columns from the spec' do
      expect(result.extra_columns).to eq('summary' => 'looks good')
    end
  end

  it 'returns parse_error when output is not structured data' do
    result = run_with(build_response(output: 'totally not json'))
    expect(result.status).to eq('parse_error')
    expect(result.parsed_score).to be_nil
    expect(store.read_raw('r1', 7, 'gpt-4o-mini')).to eq('totally not json')
  end

  it 'returns llm_error when the response carries an error' do
    result = run_with(build_response(output: '', error: 'boom 429'))
    expect(result.status).to eq('llm_error')
    expect(result.error).to eq('boom 429')
  end

  it 'returns exception status when generate raises' do
    allow(LlmConductor).to receive(:generate).and_raise(StandardError, 'network down')
    result = described_class.new(input, model: 'gpt-4o-mini', vendor: :openai, spec:,
                                        store:, run_id: 'r1', logger:).run
    expect(result.status).to eq('exception')
    expect(result.error).to match(/network down/)
  end

  describe '.slug' do
    it 'makes a filesystem-safe slug' do
      expect(described_class.slug('gemini-2.5-flash')).to eq('gemini-2.5-flash')
      expect(described_class.slug('llama3.1:8b')).to eq('llama3.1_8b')
    end
  end
end
