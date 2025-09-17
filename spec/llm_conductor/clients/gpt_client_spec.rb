# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Clients::GptClient do
  let(:model) { 'gpt-4o-mini' }
  let(:type) { :summarize_description }
  let(:client) { described_class.new(model:, type:) }

  before do
    LlmConductor.configuration.openai_api_key = 'test_api_key'
  end

  describe 'inheritance' do
    it 'inherits from BaseClient' do
      expect(client).to be_a(LlmConductor::Clients::BaseClient)
    end

    it 'includes Prompts module through inheritance' do
      expect(client).to respond_to(:prompt_summarize_description)
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
    let(:data) { { name: 'TestCorp', description: 'AI company' } }
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
