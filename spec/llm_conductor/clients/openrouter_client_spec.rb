# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Clients::OpenrouterClient do
  let(:model) { 'meta-llama/llama-3.2-90b-vision-instruct' }
  let(:type) { :summarize_htmls }
  let(:client) { described_class.new(model:, type:) }

  before do
    LlmConductor.configuration.openrouter_api_key = 'test_openrouter_key'
  end

  describe 'inheritance' do
    it 'inherits from BaseClient' do
      expect(client).to be_a(LlmConductor::Clients::BaseClient)
    end
  end

  describe '#generate_content (private)' do
    let(:prompt) { 'Test prompt for OpenRouter' }
    let(:mock_openai_client) { double('OpenAI::Client') }
    let(:api_response) do
      {
        'choices' => [
          {
            'message' => {
              'content' => 'Generated response from OpenRouter'
            }
          }
        ]
      }
    end

    before do
      allow(client).to receive(:client).and_return(mock_openai_client)
      allow(mock_openai_client).to receive(:chat).and_return(api_response)
    end

    it 'calls OpenRouter chat API with correct parameters' do
      client.send(:generate_content, prompt)

      expect(mock_openai_client).to have_received(:chat).with(
        parameters: {
          model:,
          messages: [{ role: 'user', content: prompt }],
          provider: { sort: 'throughput' }
        }
      )
    end

    it 'extracts and returns the content from API response' do
      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from OpenRouter')
    end

    it 'includes provider configuration for throughput optimization' do
      client.send(:generate_content, prompt)

      expect(mock_openai_client).to have_received(:chat) do |args|
        expect(args[:parameters][:provider]).to eq({ sort: 'throughput' })
      end
    end
  end

  describe '#client (private)' do
    let(:mock_openai_client) { double('OpenAI::Client') }

    before do
      allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
    end

    it 'creates OpenAI client with OpenRouter configuration' do
      client.send(:client)

      expect(OpenAI::Client).to have_received(:new).with(
        access_token: 'test_openrouter_key',
        uri_base: 'https://openrouter.ai/api/'
      )
    end

    it 'memoizes the client instance' do
      client1 = client.send(:client)
      client2 = client.send(:client)

      expect(client1).to be(client2)
      expect(OpenAI::Client).to have_received(:new).once
    end

    it 'uses configuration for OpenRouter API key' do
      LlmConductor.configuration.openrouter_api_key = 'different_openrouter_key'
      allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)

      client.send(:client)

      expect(OpenAI::Client).to have_received(:new).with(
        access_token: 'different_openrouter_key',
        uri_base: 'https://openrouter.ai/api/'
      )
    end
  end

  describe 'integration with base class' do
    let(:data) do
      { htmls: '<html><body><h1>AI Company</h1><p>Leading AI solutions</p></body></html>' }
    end
    let(:mock_openai_client) { double('OpenAI::Client') }
    let(:api_response) do
      {
        'choices' => [
          { 'message' => { 'content' => '{"name": "AI Company", "description": "Leading AI solutions"}' } }
        ]
      }
    end
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2 token3 token4]) }

    before do
      allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
      allow(mock_openai_client).to receive(:chat).and_return(api_response)
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'generates complete response for HTML summarization', :aggregate_failures do
      result = client.generate(data:)

      expect(result).to be_a(LlmConductor::Response)
      expect(result.output).to eq('{"name": "AI Company", "description": "Leading AI solutions"}')
      expect(result.input_tokens).to eq(4)
      expect(result.output_tokens).to eq(4)
      expect(result.metadata[:prompt]).to include('Extract useful information from the webpage')
    end
  end
end
