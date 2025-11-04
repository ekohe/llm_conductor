# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Clients::AnthropicClient do
  let(:model) { 'claude-sonnet-4-20250514' }
  let(:type) { :summarize_text }
  let(:client) { described_class.new(model:, type:) }

  before do
    LlmConductor.configuration.anthropic_api_key = 'test_api_key'
  end

  describe 'inheritance' do
    it 'inherits from BaseClient' do
      expect(client).to be_a(LlmConductor::Clients::BaseClient)
    end

    it 'includes Prompts module through inheritance' do
      expect(client).to respond_to(:prompt_summarize_text)
    end
  end

  describe '#generate_content (private)' do
    let(:prompt) { 'Test prompt for Claude' }
    let(:mock_anthropic_client) { double('Anthropic::Client') }
    let(:mock_response) { double('response', content: [double('content', text: 'Generated response from Claude')]) }

    before do
      allow(client).to receive(:client).and_return(mock_anthropic_client)
      allow(mock_anthropic_client).to receive(:messages).and_return(double('messages', create: mock_response))
    end

    it 'calls Anthropic messages API with correct parameters' do
      client.send(:generate_content, prompt)

      expect(mock_anthropic_client).to have_received(:messages)
      expect(mock_anthropic_client.messages).to have_received(:create).with(
        model:,
        max_tokens: 4096,
        messages: [{ role: 'user', content: prompt }]
      )
    end

    it 'extracts and returns the content from API response' do
      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from Claude')
    end

    it 'handles API response structure correctly' do
      allow(mock_anthropic_client).to receive(:messages).and_return(double('messages', create: mock_response))

      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from Claude')
    end

    it 'handles Anthropic API errors' do
      messages_mock = double('messages')
      allow(messages_mock).to receive(:create).and_raise(Anthropic::Errors::APIError.new(url: 'https://api.anthropic.com'))
      allow(mock_anthropic_client).to receive(:messages).and_return(messages_mock)

      expect { client.send(:generate_content, prompt) }.to raise_error(StandardError, /Anthropic API error:/)
    end
  end

  describe '#format_content (private)' do
    it 'returns string as-is for simple prompts' do
      result = client.send(:format_content, 'Simple text')
      expect(result).to eq('Simple text')
    end

    it 'returns array as-is for pre-formatted content' do
      formatted = [{ type: 'text', text: 'Hello' }]
      result = client.send(:format_content, formatted)
      expect(result).to eq(formatted)
    end

    it 'converts hash with text and image to multimodal array' do
      hash_prompt = { text: 'What is this?', images: 'https://example.com/image.jpg' }
      result = client.send(:format_content, hash_prompt)

      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      expect(result[0]).to eq({ type: 'image', source: { type: 'url', url: 'https://example.com/image.jpg' } })
      expect(result[1]).to eq({ type: 'text', text: 'What is this?' })
    end
  end

  describe '#format_multimodal_hash (private)' do
    it 'handles single image URL' do
      hash = { text: 'Describe this', images: 'https://example.com/image.jpg' }
      result = client.send(:format_multimodal_hash, hash)

      expect(result).to eq([
                             { type: 'image', source: { type: 'url', url: 'https://example.com/image.jpg' } },
                             { type: 'text', text: 'Describe this' }
                           ])
    end

    it 'handles multiple image URLs' do
      hash = {
        text: 'Compare these',
        images: ['https://example.com/1.jpg', 'https://example.com/2.jpg']
      }
      result = client.send(:format_multimodal_hash, hash)

      expect(result.size).to eq(3)
      expect(result[0][:type]).to eq('image')
      expect(result[1][:type]).to eq('image')
      expect(result[2][:type]).to eq('text')
    end

    it 'handles images with url in hash format' do
      hash = {
        text: 'Analyze',
        images: [{ url: 'https://example.com/image.jpg' }]
      }
      result = client.send(:format_multimodal_hash, hash)

      expect(result[0]).to eq({
                                type: 'image',
                                source: { type: 'url', url: 'https://example.com/image.jpg' }
                              })
    end

    it 'handles text-only hash' do
      hash = { text: 'Just text' }
      result = client.send(:format_multimodal_hash, hash)

      expect(result).to eq([{ type: 'text', text: 'Just text' }])
    end

    it 'places images before text (Anthropic recommendation)' do
      hash = { text: 'Describe', images: 'https://example.com/image.jpg' }
      result = client.send(:format_multimodal_hash, hash)

      expect(result[0][:type]).to eq('image')
      expect(result[1][:type]).to eq('text')
    end
  end

  describe '#calculate_tokens (private)' do
    let(:mock_encoder) { double('encoder') }

    before do
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'calculates tokens for string content' do
      allow(mock_encoder).to receive(:encode).with('test').and_return(%w[t e s t])
      result = client.send(:calculate_tokens, 'test')
      expect(result).to eq(4)
    end

    it 'calculates tokens for hash with text' do
      allow(mock_encoder).to receive(:encode).with('analyze this').and_return(%w[a n a l y z e])
      hash = { text: 'analyze this', images: 'https://example.com/image.jpg' }
      result = client.send(:calculate_tokens, hash)
      expect(result).to eq(7)
    end

    it 'calculates tokens for array content' do
      allow(mock_encoder).to receive(:encode).with('hello world').and_return(%w[h e l l o])
      array = [
        { type: 'image', source: { type: 'url', url: 'https://example.com/image.jpg' } },
        { type: 'text', text: 'hello' },
        { type: 'text', text: 'world' }
      ]
      result = client.send(:calculate_tokens, array)
      expect(result).to eq(5)
    end
  end

  describe '#client (private)' do
    let(:mock_anthropic_client) { double('Anthropic::Client') }

    before do
      allow(Anthropic::Client).to receive(:new).and_return(mock_anthropic_client)
    end

    it 'creates Anthropic client with API key' do
      client.send(:client)

      expect(Anthropic::Client).to have_received(:new).with(
        api_key: 'test_api_key'
      )
    end

    it 'memoizes the client instance' do
      client1 = client.send(:client)
      client2 = client.send(:client)

      expect(client1).to be(client2)
      expect(Anthropic::Client).to have_received(:new).once
    end

    it 'uses configuration for API key' do
      LlmConductor.configuration.anthropic_api_key = 'different_key'
      allow(Anthropic::Client).to receive(:new).and_return(mock_anthropic_client)

      client.send(:client)

      expect(Anthropic::Client).to have_received(:new).with(
        api_key: 'different_key'
      )
    end
  end

  describe 'integration with base class' do
    let(:data) { { text: 'TestCorp is an AI company specializing in machine learning solutions.' } }
    let(:mock_anthropic_client) { double('Anthropic::Client') }
    let(:mock_response) { double('response', content: [double('content', text: 'Claude response')]) }
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2 token3]) }

    before do
      allow(Anthropic::Client).to receive(:new).and_return(mock_anthropic_client)
      allow(mock_anthropic_client).to receive(:messages).and_return(double('messages', create: mock_response))
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'generates complete response with tokens', :aggregate_failures do
      result = client.generate(data:)

      expect(result).to be_a(LlmConductor::Response)
      expect(result.output).to eq('Claude response')
      expect(result.input_tokens).to eq(3)
      expect(result.output_tokens).to eq(3)
      expect(result.metadata[:prompt]).to include('TestCorp')
    end
  end
end
