# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Clients::OllamaClient do
  let(:model) { 'llama2' }
  let(:type) { :custom }
  let(:params) { { temperature: 0.7, top_p: 0.9 } }
  let(:client) { described_class.new(model:, type:, params:) }

  before do
    LlmConductor.configure do |config|
      config.ollama(base_url: 'http://localhost:11434')
    end
  end

  describe 'initialization with params' do
    it 'stores params' do
      expect(client.params).to eq(params)
    end

    it 'works without params' do
      client_without_params = described_class.new(model:, type:)
      expect(client_without_params.params).to eq({})
    end
  end

  describe '#generate_simple' do
    let(:prompt) { 'Hello, world!' }
    let(:mock_ollama_client) { double('Ollama') }
    let(:mock_response) { [{ 'response' => 'Hi there!' }] }
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2]) }

    before do
      allow(client).to receive(:client).and_return(mock_ollama_client)
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'passes params to the Ollama API' do
      expected_request = {
        model:,
        prompt:,
        stream: false,
        temperature: 0.7,
        top_p: 0.9
      }

      allow(mock_ollama_client).to receive(:generate).and_return(mock_response)

      response = client.generate_simple(prompt:)

      expect(response.output).to eq('Hi there!')
      expect(response.success?).to be true
      expect(mock_ollama_client).to have_received(:generate).with(expected_request)
    end

    it 'works without params' do
      client_without_params = described_class.new(model:, type:)
      allow(client_without_params).to receive(:client).and_return(mock_ollama_client)

      expected_request = {
        model:,
        prompt:,
        stream: false
      }

      allow(mock_ollama_client).to receive(:generate).and_return(mock_response)

      response = client_without_params.generate_simple(prompt:)

      expect(response.output).to eq('Hi there!')
      expect(mock_ollama_client).to have_received(:generate).with(expected_request)
    end
  end

  describe '#generate with data' do
    let(:data) { { content: 'Test content' } }
    let(:mock_ollama_client) { double('Ollama') }
    let(:mock_response) { [{ 'response' => 'Processed content' }] }
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2]) }

    before do
      allow(client).to receive_messages(client: mock_ollama_client, prompt_custom: 'Custom prompt: Test content')
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'passes params when using template-based generation' do
      allow(mock_ollama_client).to receive(:generate).and_return(mock_response)

      response = client.generate(data:)

      expect(response.output).to eq('Processed content')
      expect(mock_ollama_client).to have_received(:generate)
        .with(hash_including(temperature: 0.7, top_p: 0.9))
    end
  end
end
