# frozen_string_literal: true

require_relative 'support'

RSpec.describe LlmConductor::Eval::JsonParser do
  describe '.parse' do
    it 'parses plain valid JSON unchanged' do
      expect(described_class.parse('{"score": 80, "ok": true}'))
        .to eq('score' => 80, 'ok' => true)
    end

    it 'does not corrupt numeric values (no over-eager repair)' do
      expect(described_class.parse('{"quality_score": 100}'))
        .to eq('quality_score' => 100)
    end

    it 'strips ```json fences' do
      expect(described_class.parse("```json\n{\"a\": 1}\n```")).to eq('a' => 1)
    end

    it 'strips bare ``` fences' do
      expect(described_class.parse("```\n{\"a\": 1}\n```")).to eq('a' => 1)
    end

    it 'drops preamble before the first brace' do
      expect(described_class.parse("Sure! Here is the JSON:\n{\"a\": 1}"))
        .to eq('a' => 1)
    end

    it 'trims trailing commentary after the balanced object' do
      expect(described_class.parse('{"a": 1} -- hope this helps!')).to eq('a' => 1)
    end

    it 'parses top-level arrays' do
      expect(described_class.parse('[{"a": 1}, {"b": 2}]'))
        .to eq([{ 'a' => 1 }, { 'b' => 2 }])
    end

    it 'is not fooled by braces inside string literals' do
      expect(described_class.parse('{"note": "a } in a string", "x": 1}'))
        .to eq('note' => 'a } in a string', 'x' => 1)
    end

    it 'returns nil for non-JSON text' do
      expect(described_class.parse('no json here at all')).to be_nil
    end

    it 'returns nil for empty / nil input' do
      expect(described_class.parse('')).to be_nil
      expect(described_class.parse(nil)).to be_nil
    end

    it 'returns nil for the real Phi-3 malformed fixture' do
      raw = File.read(File.expand_path('../../fixtures/files/startup_evaluation_phi3_malformed.json', __dir__))
      expect(described_class.parse(raw)).to be_nil
    end
  end
end
