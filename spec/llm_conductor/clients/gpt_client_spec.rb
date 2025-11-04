# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Clients::GptClient do
  let(:model) { 'gpt-4o-mini' }
  let(:type) { :summarize_text }
  let(:client) { described_class.new(model:, type:) }

  before do
    LlmConductor.configuration.openai_api_key = 'test_api_key'
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
    let(:prompt) { 'Test prompt for GPT' }
    let(:mock_openai_client) { double('OpenAI::Client') }
    let(:api_response) do
      {
        'choices' => [
          {
            'message' => {
              'content' => 'Generated response from GPT'
            }
          }
        ]
      }
    end

    before do
      allow(client).to receive(:client).and_return(mock_openai_client)
      allow(mock_openai_client).to receive(:chat).and_return(api_response)
    end

    it 'calls OpenAI chat API with correct parameters' do
      client.send(:generate_content, prompt)

      expect(mock_openai_client).to have_received(:chat).with(
        parameters: {
          model:,
          messages: [{ role: 'user', content: prompt }]
        }
      )
    end

    it 'extracts and returns the content from API response' do
      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from GPT')
    end

    it 'handles API response structure correctly' do
      allow(mock_openai_client).to receive(:chat).and_return(api_response)

      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from GPT')
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
      expect(result[0]).to eq({ type: 'text', text: 'What is this?' })
      expect(result[1]).to eq({ type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } })
    end
  end

  describe '#format_multimodal_hash (private)' do
    it 'handles single image URL' do
      hash = { text: 'Describe this', images: 'https://example.com/image.jpg' }
      result = client.send(:format_multimodal_hash, hash)

      expect(result).to eq([
                             { type: 'text', text: 'Describe this' },
                             { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } }
                           ])
    end

    it 'handles multiple image URLs' do
      hash = {
        text: 'Compare these',
        images: ['https://example.com/1.jpg', 'https://example.com/2.jpg']
      }
      result = client.send(:format_multimodal_hash, hash)

      expect(result.size).to eq(3)
      expect(result[0][:type]).to eq('text')
      expect(result[1][:type]).to eq('image_url')
      expect(result[2][:type]).to eq('image_url')
    end

    it 'handles images with detail level' do
      hash = {
        text: 'Analyze',
        images: [{ url: 'https://example.com/image.jpg', detail: 'high' }]
      }
      result = client.send(:format_multimodal_hash, hash)

      expect(result[1]).to eq({
                                type: 'image_url',
                                image_url: { url: 'https://example.com/image.jpg', detail: 'high' }
                              })
    end

    it 'handles text-only hash' do
      hash = { text: 'Just text' }
      result = client.send(:format_multimodal_hash, hash)

      expect(result).to eq([{ type: 'text', text: 'Just text' }])
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
        { type: 'text', text: 'hello' },
        { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } },
        { type: 'text', text: 'world' }
      ]
      result = client.send(:calculate_tokens, array)
      expect(result).to eq(5)
    end
  end

  describe '#client (private)' do
    let(:mock_openai_client) { double('OpenAI::Client') }

    before do
      allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
    end

    it 'creates OpenAI client with access token' do
      client.send(:client)

      expect(OpenAI::Client).to have_received(:new).with(
        access_token: 'test_api_key'
      )
    end

    it 'memoizes the client instance' do
      client1 = client.send(:client)
      client2 = client.send(:client)

      expect(client1).to be(client2)
      expect(OpenAI::Client).to have_received(:new).once
    end

    it 'uses configuration for API key' do
      LlmConductor.configuration.openai_api_key = 'different_key'
      allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)

      client.send(:client)

      expect(OpenAI::Client).to have_received(:new).with(
        access_token: 'different_key'
      )
    end
  end

  describe 'integration with base class' do
    let(:data) { { text: 'TestCorp is an AI company specializing in machine learning solutions.' } }
    let(:mock_openai_client) { double('OpenAI::Client') }
    let(:api_response) do
      {
        'choices' => [
          { 'message' => { 'content' => 'GPT response' } }
        ]
      }
    end
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2 token3]) }

    before do
      allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
      allow(mock_openai_client).to receive(:chat).and_return(api_response)
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'generates complete response with tokens', :aggregate_failures do
      result = client.generate(data:)

      expect(result).to be_a(LlmConductor::Response)
      expect(result.output).to eq('GPT response')
      expect(result.input_tokens).to eq(3)
      expect(result.output_tokens).to eq(3)
      expect(result.metadata[:prompt]).to include('TestCorp')
    end
  end
end
