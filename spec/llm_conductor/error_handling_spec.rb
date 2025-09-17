# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'LlmConductor Error Handling' do
  describe 'configuration errors' do
    context 'with missing API keys' do
      before do
        LlmConductor.configure do |config|
          config.openai_api_key = nil
          config.openrouter_api_key = nil
        end
      end

      it 'handles missing OpenAI API key gracefully in GPT client' do
        client = LlmConductor.build_client(model: 'gpt-4o-mini', type: :summarize_description)

        # The client should be created, but API calls may fail
        expect(client).to be_a(LlmConductor::Clients::GptClient)
        expect(client.send(:client)).to be_a(OpenAI::Client)
      end

      it 'handles missing OpenRouter API key gracefully in OpenRouter client' do
        client = LlmConductor.build_client(model: 'llama-3.2', type: :featured_links, vendor: :openrouter)

        expect(client).to be_a(LlmConductor::Clients::OpenrouterClient)
        expect(client.send(:client)).to be_a(OpenAI::Client)
      end
    end

    context 'with invalid configuration' do
      it 'handles invalid Ollama address gracefully' do
        LlmConductor.configure do |config|
          config.ollama_address = 'invalid-url'
        end

        client = LlmConductor.build_client(model: 'llama2', type: :custom)

        expect(client).to be_a(LlmConductor::Clients::OllamaClient)
        # The client creation should succeed, connection errors would occur during generate
      end
    end
  end

  describe 'API errors' do
    let(:data) { { name: 'TestCorp', description: 'Test company' } }

    context 'with OpenAI API errors' do
      let(:mock_openai_client) { double('OpenAI::Client') }

      before do
        LlmConductor.configuration.openai_api_key = 'test_key'
        allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
      end

      it 'handles network errors gracefully' do
        allow(mock_openai_client).to receive(:chat).and_raise(StandardError, 'Request timeout')
        client = LlmConductor.build_client(model: 'gpt-4o-mini', type: :summarize_description)

        result = client.generate(data:)
        expect(result).to be_a(LlmConductor::Response)
        expect(result.success?).to be false
        expect(result.metadata[:error]).to include('Request timeout')
      end

      it 'handles API authentication errors gracefully' do
        allow(mock_openai_client).to receive(:chat).and_raise(StandardError, 'Unauthorized')
        client = LlmConductor.build_client(model: 'gpt-4o-mini', type: :summarize_description)

        result = client.generate(data:)
        expect(result).to be_a(LlmConductor::Response)
        expect(result.success?).to be false
        expect(result.metadata[:error]).to include('Unauthorized')
      end

      it 'handles malformed API responses gracefully' do
        allow(mock_openai_client).to receive(:chat).and_return({})
        client = LlmConductor.build_client(model: 'gpt-4o-mini', type: :summarize_description)

        result = client.generate(data:)
        expect(result).to be_a(LlmConductor::Response)
        expect(result.success?).to be false
        # With malformed response, we get nil output which makes success? false
        expect(result.output).to be_nil
      end
    end

    context 'with Ollama API errors' do
      let(:mock_ollama_client) { double('Ollama') }

      before do
        allow(Ollama).to receive(:new).and_return(mock_ollama_client)
      end

      it 'handles connection errors gracefully' do
        allow(mock_ollama_client).to receive(:generate).and_raise(Errno::ECONNREFUSED)
        client = LlmConductor.build_client(model: 'llama2', type: :summarize_description)

        result = client.generate(data:)
        expect(result).to be_a(LlmConductor::Response)
        expect(result.success?).to be false
        expect(result.metadata[:error]).to match(/Connection refused|ECONNREFUSED/)
      end

      it 'handles empty responses gracefully' do
        allow(mock_ollama_client).to receive(:generate).and_return([])
        client = LlmConductor.build_client(model: 'llama2', type: :summarize_description)

        result = client.generate(data:)
        expect(result).to be_a(LlmConductor::Response)
        expect(result.success?).to be false
        expect(result.metadata).to have_key(:error)
      end
    end
  end

  describe 'prompt errors' do
    let(:mock_openai_client) { double('OpenAI::Client') }
    let(:api_response) do
      { 'choices' => [{ 'message' => { 'content' => 'Response' } }] }
    end

    before do
      LlmConductor.configuration.openai_api_key = 'test_key'
      allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
      allow(mock_openai_client).to receive(:chat).and_return(api_response)
    end

    it 'handles undefined prompt methods gracefully' do
      client = LlmConductor.build_client(model: 'gpt-4o-mini', type: :nonexistent_prompt)

      result = client.generate(data: {})
      expect(result).to be_a(LlmConductor::Response)
      expect(result.success?).to be false
      expect(result.metadata[:error]).to match(/NoMethodError|undefined method/)
    end

    it 'handles missing required prompt data for custom prompts gracefully' do
      client = LlmConductor.build_client(model: 'gpt-4o-mini', type: :custom)

      result = client.generate(data: {})
      expect(result).to be_a(LlmConductor::Response)
      expect(result.success?).to be false
      expect(result.metadata[:error]).to match(/KeyError|key.*not found/)
    end

    it 'handles missing interpolation keys in custom templates gracefully' do
      client = LlmConductor.build_client(model: 'gpt-4o-mini', type: :custom)

      result = client.generate(data: { template: 'Hello %<name>s' })
      expect(result).to be_a(LlmConductor::Response)
      expect(result.success?).to be false
      expect(result.metadata[:error]).to match(/KeyError|key.*not found/)
    end
  end

  describe 'token calculation errors' do
    let(:mock_openai_client) { double('OpenAI::Client') }
    let(:api_response) do
      { 'choices' => [{ 'message' => { 'content' => 'Response' } }] }
    end

    before do
      LlmConductor.configuration.openai_api_key = 'test_key'
      allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
      allow(mock_openai_client).to receive(:chat).and_return(api_response)
    end

    it 'handles tiktoken encoding errors gracefully' do
      allow(Tiktoken).to receive(:get_encoding).and_raise(StandardError, 'Encoding error')
      client = LlmConductor.build_client(model: 'gpt-4o-mini', type: :summarize_description)

      result = client.generate(data: { name: 'TestCorp' })
      expect(result).to be_a(LlmConductor::Response)
      expect(result.success?).to be false
      expect(result.metadata[:error]).to include('Encoding error')
    end
  end

  describe 'client factory errors' do
    it 'creates appropriate clients even with unusual model names' do
      # Should create Ollama client for non-GPT model
      client = LlmConductor.build_client(model: 'unusual-model-name', type: :custom)
      expect(client).to be_a(LlmConductor::Clients::OllamaClient)
    end

    it 'handles edge case model names correctly' do
      # Model name containing "gpt" but not starting with it
      client = LlmConductor.build_client(model: 'custom-gpt-model', type: :custom)
      expect(client).to be_a(LlmConductor::Clients::OllamaClient)

      # Model starting with "gpt"
      client = LlmConductor.build_client(model: 'gpt-custom', type: :custom)
      expect(client).to be_a(LlmConductor::Clients::GptClient)
    end
  end
end
