# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Clients::GroqClient do
  let(:model) { 'llama-3.1-70b-versatile' }
  let(:type) { :summarize_text }
  let(:client) { described_class.new(model:, type:) }

  before do
    LlmConductor.configuration.groq_api_key = 'test_api_key'
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
    let(:prompt) { 'Test prompt for Groq' }
    let(:mock_groq_client) { double('Groq::Client') }
    let(:api_response) do
      {
        'choices' => [
          {
            'message' => {
              'content' => 'Generated response from Groq'
            }
          }
        ]
      }
    end

    before do
      allow(client).to receive(:client).and_return(mock_groq_client)
      allow(mock_groq_client).to receive(:chat).and_return(api_response)
    end

    it 'calls Groq chat API with correct parameters' do
      client.send(:generate_content, prompt)

      expect(mock_groq_client).to have_received(:chat).with(
        messages: [{ role: 'user', content: prompt }],
        model:
      )
    end

    it 'extracts and returns the content from API response' do
      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from Groq')
    end

    it 'handles API response structure correctly' do
      allow(mock_groq_client).to receive(:chat).and_return(api_response)

      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from Groq')
    end
  end

  describe '#client (private)' do
    let(:mock_groq_client) { double('Groq::Client') }

    before do
      allow(Groq::Client).to receive(:new).and_return(mock_groq_client)
    end

    it 'creates Groq client with API key' do
      client.send(:client)

      expect(Groq::Client).to have_received(:new).with(
        api_key: 'test_api_key'
      )
    end

    it 'memoizes the client instance' do
      client1 = client.send(:client)
      client2 = client.send(:client)

      expect(client1).to be(client2)
      expect(Groq::Client).to have_received(:new).once
    end

    it 'uses configuration for API key' do
      LlmConductor.configuration.groq_api_key = 'different_key'
      allow(Groq::Client).to receive(:new).and_return(mock_groq_client)

      client.send(:client)

      expect(Groq::Client).to have_received(:new).with(
        api_key: 'different_key'
      )
    end
  end

  describe 'integration with base class' do
    let(:data) { { text: 'TestCorp is an AI company specializing in machine learning solutions.' } }
    let(:mock_groq_client) { double('Groq::Client') }
    let(:api_response) do
      {
        'choices' => [
          { 'message' => { 'content' => 'Groq response' } }
        ]
      }
    end
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2 token3]) }

    before do
      allow(Groq::Client).to receive(:new).and_return(mock_groq_client)
      allow(mock_groq_client).to receive(:chat).and_return(api_response)
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'generates complete response with tokens', :aggregate_failures do
      result = client.generate(data:)

      expect(result).to be_a(LlmConductor::Response)
      expect(result.output).to eq('Groq response')
      expect(result.input_tokens).to eq(3)
      expect(result.output_tokens).to eq(3)
      expect(result.metadata[:prompt]).to include('TestCorp')
    end
  end

  describe 'vendor name' do
    it 'returns correct vendor name' do
      expect(client.send(:vendor_name)).to eq(:groq)
    end
  end
end
