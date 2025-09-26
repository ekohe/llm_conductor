# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Clients::OllamaClient do
  let(:model) { 'llama2' }
  let(:type) { :extract_links }
  let(:client) { described_class.new(model:, type:) }

  before do
    LlmConductor.configuration.ollama_address = 'http://test.ollama:11434'
  end

  describe 'inheritance' do
    it 'inherits from BaseClient' do
      expect(client).to be_a(LlmConductor::Clients::BaseClient)
    end
  end

  describe '#generate_content (private)' do
    let(:prompt) { 'Test prompt for Ollama' }
    let(:mock_ollama_client) { double('Ollama') }
    let(:api_response) do
      [{ 'response' => 'Generated response from Ollama' }]
    end

    before do
      allow(client).to receive(:client).and_return(mock_ollama_client)
      allow(mock_ollama_client).to receive(:generate).and_return(api_response)
    end

    it 'calls Ollama generate API with correct parameters' do
      client.send(:generate_content, prompt)

      expect(mock_ollama_client).to have_received(:generate).with(
        model:,
        prompt:,
        stream: false
      )
    end

    it 'extracts and returns the response from API response' do
      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from Ollama')
    end

    it 'handles API response array structure correctly' do
      custom_response = [{ 'response' => 'Custom Ollama response' }]
      allow(mock_ollama_client).to receive(:generate).and_return(custom_response)

      result = client.send(:generate_content, prompt)

      expect(result).to eq('Custom Ollama response')
    end
  end

  describe '#client (private)' do
    let(:mock_ollama_client) { double('Ollama') }

    before do
      allow(Ollama).to receive(:new).and_return(mock_ollama_client)
    end

    it 'creates Ollama client with correct configuration' do
      client.send(:client)

      expect(Ollama).to have_received(:new).with(
        credentials: { address: 'http://test.ollama:11434' },
        options: { server_sent_events: true }
      )
    end

    it 'memoizes the client instance' do
      client1 = client.send(:client)
      client2 = client.send(:client)

      expect(client1).to be(client2)
      expect(Ollama).to have_received(:new).once
    end

    it 'uses configuration for ollama address' do
      LlmConductor.configuration.ollama_address = 'http://different.ollama:11434'
      allow(Ollama).to receive(:new).and_return(mock_ollama_client)

      client.send(:client)

      expect(Ollama).to have_received(:new).with(
        credentials: { address: 'http://different.ollama:11434' },
        options: { server_sent_events: true }
      )
    end
  end

  describe 'integration with base class' do
    let(:data) do
      {
        htmls: '<html><a href="/about">About</a></html>',
        current_url: 'https://example.com'
      }
    end
    let(:mock_ollama_client) { double('Ollama') }
    let(:api_response) { [{ 'response' => '["https://example.com/about"]' }] }
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2]) }

    before do
      allow(Ollama).to receive(:new).and_return(mock_ollama_client)
      allow(mock_ollama_client).to receive(:generate).and_return(api_response)
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'generates complete response for link extraction', :aggregate_failures do
      result = client.generate(data:)

      expect(result).to be_a(LlmConductor::Response)
      expect(result.output).to eq('["https://example.com/about"]')
      expect(result.input_tokens).to eq(2)
      expect(result.output_tokens).to eq(2)
      expect(result.metadata[:prompt]).to include('Analyze the provided HTML content and extract links')
    end
  end
end
