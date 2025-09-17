# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Response, 'enhancements' do
  let(:valid_json_output) do
    {
      business_model: 'SaaS platform',
      target_market: 'Enterprise clients',
      competitive_advantages: ['AI technology', 'User-friendly interface'],
      growth_potential: 'high'
    }.to_json
  end

  let(:malformed_json_output) { '{"incomplete": "json"' }
  let(:text_output) { 'This is just plain text, not JSON.' }

  describe '#parse_json' do
    context 'when response is successful and contains valid JSON' do
      let(:response) do
        described_class.new(
          output: valid_json_output,
          model: 'gpt-4',
          input_tokens: 50,
          output_tokens: 100,
          metadata: {}
        )
      end

      it 'parses the JSON output successfully' do
        result = response.parse_json
        expect(result).to be_a(Hash)
        expect(result['business_model']).to eq('SaaS platform')
        expect(result['competitive_advantages']).to eq(['AI technology', 'User-friendly interface'])
      end

      it 'handles JSON with whitespace' do
        whitespace_response = described_class.new(
          output: "  #{valid_json_output}  \n",
          model: 'gpt-4',
          metadata: {}
        )

        result = whitespace_response.parse_json
        expect(result).to be_a(Hash)
        expect(result['business_model']).to eq('SaaS platform')
      end
    end

    context 'when response contains malformed JSON' do
      let(:response) do
        described_class.new(
          output: malformed_json_output,
          model: 'gpt-4',
          metadata: {}
        )
      end

      it 'raises JSON::ParserError with helpful message' do
        expect { response.parse_json }.to raise_error(JSON::ParserError) do |error|
          expect(error.message).to include('Failed to parse JSON response')
        end
      end
    end

    context 'when response is not successful' do
      let(:response) do
        described_class.new(
          output: nil,
          model: 'gpt-4',
          metadata: { error: 'API error' }
        )
      end

      it 'returns nil' do
        expect(response.parse_json).to be_nil
      end
    end

    context 'when output is empty' do
      let(:response) do
        described_class.new(
          output: '',
          model: 'gpt-4',
          metadata: {}
        )
      end

      it 'returns nil' do
        expect(response.parse_json).to be_nil
      end
    end

    context 'when output is plain text' do
      let(:response) do
        described_class.new(
          output: text_output,
          model: 'gpt-4',
          metadata: {}
        )
      end

      it 'raises JSON::ParserError' do
        expect { response.parse_json }.to raise_error(JSON::ParserError)
      end
    end
  end

  describe '#extract_code_block' do
    let(:output_with_code_blocks) do
      <<~TEXT
        Here's the analysis:

        ```json
        {"result": "success", "data": [1, 2, 3]}
        ```

        And here's some Python code:

        ```python
        def hello():
            print("Hello world")
        ```

        ```
        Some code without language specified
        ```
      TEXT
    end

    let(:response) do
      described_class.new(
        output: output_with_code_blocks,
        model: 'gpt-4',
        metadata: {}
      )
    end

    context 'with specific language' do
      it 'extracts JSON code block' do
        result = response.extract_code_block('json')
        expect(result).to eq('{"result": "success", "data": [1, 2, 3]}')
      end

      it 'extracts Python code block' do
        result = response.extract_code_block('python')
        expected = "def hello():\n    print(\"Hello world\")"
        expect(result).to eq(expected)
      end

      it 'returns nil for non-existent language' do
        result = response.extract_code_block('ruby')
        expect(result).to be_nil
      end
    end

    context 'without specific language' do
      it 'extracts first code block found' do
        result = response.extract_code_block
        expect(result).to eq('{"result": "success", "data": [1, 2, 3]}')
      end
    end

    context 'when no code blocks exist' do
      let(:response_no_blocks) do
        described_class.new(
          output: 'Just plain text without any code blocks',
          model: 'gpt-4',
          metadata: {}
        )
      end

      it 'returns nil' do
        expect(response_no_blocks.extract_code_block).to be_nil
        expect(response_no_blocks.extract_code_block('json')).to be_nil
      end
    end

    context 'when output is nil' do
      let(:response_nil_output) do
        described_class.new(
          output: nil,
          model: 'gpt-4',
          metadata: {}
        )
      end

      it 'returns nil' do
        expect(response_nil_output.extract_code_block).to be_nil
      end
    end

    context 'with malformed code blocks' do
      let(:malformed_response) do
        described_class.new(
          output: '```json\n{"incomplete": "json"',
          model: 'gpt-4',
          metadata: {}
        )
      end

      it 'returns nil when closing block is missing' do
        expect(malformed_response.extract_code_block('json')).to be_nil
      end
    end
  end

  describe 'integration with parse_json and extract_code_block' do
    let(:output_with_json_block) do
      <<~TEXT
        Here's the analysis result:

        ```json
        {
          "business_model": "SaaS platform",
          "target_market": "Enterprise clients",
          "growth_potential": "high"
        }
        ```

        This data shows promising results.
      TEXT
    end

    let(:response) do
      described_class.new(
        output: output_with_json_block,
        model: 'gpt-4',
        metadata: {}
      )
    end

    it 'can extract and parse JSON from code blocks' do
      json_code = response.extract_code_block('json')
      expect(json_code).to include('business_model')

      # Create a temporary response with just the JSON
      json_response = described_class.new(
        output: json_code,
        model: 'gpt-4',
        metadata: {}
      )

      parsed = json_response.parse_json
      expect(parsed['business_model']).to eq('SaaS platform')
      expect(parsed['growth_potential']).to eq('high')
    end
  end
end
