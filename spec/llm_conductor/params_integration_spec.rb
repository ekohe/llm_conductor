# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Params Integration' do
  before do
    LlmConductor.configure do |config|
      config.ollama(base_url: 'http://localhost:11434')
    end
  end

  describe 'LlmConductor.generate with params' do
    let(:mock_ollama_client) { double('Ollama') }
    let(:mock_response) { [{ 'response' => 'Test response' }] }
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2]) }

    before do
      allow(Ollama).to receive(:new).and_return(mock_ollama_client)
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'accepts and passes params for simple prompt generation' do
      allow(mock_ollama_client).to receive(:generate).and_return(mock_response)

      response = LlmConductor.generate(
        model: 'llama2',
        prompt: 'Hello',
        vendor: :ollama,
        params: { temperature: 0.8, top_p: 0.9 }
      )

      expect(response.output).to eq('Test response')
      expect(response.success?).to be true
      expect(mock_ollama_client).to have_received(:generate)
        .with(hash_including(temperature: 0.8, top_p: 0.9))
    end

    it 'works without params' do
      allow(mock_ollama_client).to receive(:generate).and_return(mock_response)

      response = LlmConductor.generate(
        model: 'llama2',
        prompt: 'Hello',
        vendor: :ollama
      )

      expect(response.output).to eq('Test response')
      expect(mock_ollama_client).to have_received(:generate)
        .with(hash_including(model: 'llama2', prompt: 'Hello', stream: false))
    end

    it 'accepts params for template-based generation' do
      allow(mock_ollama_client).to receive(:generate).and_return(mock_response)

      # Using custom type with mock prompt
      client = LlmConductor.build_client(
        model: 'llama2',
        type: :custom,
        vendor: :ollama,
        params: { temperature: 0.5 }
      )

      allow(client).to receive(:prompt_custom).and_return('Custom prompt')

      response = client.generate(data: { content: 'Test' })

      expect(response.output).to eq('Test response')
      expect(mock_ollama_client).to have_received(:generate)
        .with(hash_including(temperature: 0.5))
    end
  end

  describe 'LlmConductor.build_client with params' do
    it 'creates client with params' do
      client = LlmConductor.build_client(
        model: 'llama2',
        type: :custom,
        vendor: :ollama,
        params: { temperature: 0.3, num_predict: 100 }
      )

      expect(client).to be_a(LlmConductor::Clients::OllamaClient)
      expect(client.params).to eq({ temperature: 0.3, num_predict: 100 })
    end

    it 'creates client without params' do
      client = LlmConductor.build_client(
        model: 'llama2',
        type: :custom,
        vendor: :ollama
      )

      expect(client.params).to eq({})
    end
  end

  describe 'ClientFactory with params' do
    it 'passes params to client constructor' do
      client = LlmConductor::ClientFactory.build(
        model: 'llama2',
        type: :custom,
        vendor: :ollama,
        params: { temperature: 0.9 }
      )

      expect(client.params).to eq({ temperature: 0.9 })
    end
  end
end
