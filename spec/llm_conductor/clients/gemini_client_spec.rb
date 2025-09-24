# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Clients::GeminiClient do
  let(:model) { 'gemini-1.5-flash' }
  let(:type) { :summarize_description }
  let(:client) { described_class.new(model:, type:) }

  before do
    LlmConductor.configuration.gemini_api_key = 'test_api_key'
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
    let(:prompt) { 'Test prompt for Gemini' }
    let(:mock_gemini_client) { double('Gemini') }
    let(:api_response) do
      {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => 'Generated response from Gemini' }
              ]
            }
          }
        ]
      }
    end

    before do
      allow(client).to receive(:client).and_return(mock_gemini_client)
      allow(mock_gemini_client).to receive(:generate_content).and_return(api_response)
    end

    it 'calls Gemini API with correct parameters' do
      client.send(:generate_content, prompt)

      expect(mock_gemini_client).to have_received(:generate_content).with(
        {
          contents: [
            { parts: [{ text: prompt }] }
          ]
        }
      )
    end

    it 'extracts and returns the content from API response' do
      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from Gemini')
    end

    it 'handles nested response structure with dig' do
      custom_response = {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => 'Custom Gemini response' }
              ]
            }
          }
        ]
      }
      allow(mock_gemini_client).to receive(:generate_content).and_return(custom_response)

      result = client.send(:generate_content, prompt)

      expect(result).to eq('Custom Gemini response')
    end
  end

  describe '#client (private)' do
    let(:mock_gemini_client) { double('Gemini') }

    before do
      allow(Gemini).to receive(:new).and_return(mock_gemini_client)
    end

    it 'creates Gemini client with API key and model' do
      client.send(:client)

      expect(Gemini).to have_received(:new).with(
        credentials: {
          service: 'generative-language-api',
          api_key: 'test_api_key'
        },
        options: { model: }
      )
    end

    it 'memoizes the client instance' do
      client1 = client.send(:client)
      client2 = client.send(:client)

      expect(client1).to be(client2)
      expect(Gemini).to have_received(:new).once
    end

    it 'uses configuration for API key' do
      LlmConductor.configuration.gemini_api_key = 'different_key'
      allow(Gemini).to receive(:new).and_return(mock_gemini_client)

      client.send(:client)

      expect(Gemini).to have_received(:new).with(
        credentials: {
          service: 'generative-language-api',
          api_key: 'different_key'
        },
        options: { model: }
      )
    end
  end

  describe 'integration with base class' do
    let(:data) { { name: 'TestCorp', description: 'AI company' } }
    let(:mock_gemini_client) { double('Gemini') }
    let(:api_response) do
      {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => 'Gemini response' }
              ]
            }
          }
        ]
      }
    end
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2 token3]) }

    before do
      allow(Gemini).to receive(:new).and_return(mock_gemini_client)
      allow(mock_gemini_client).to receive(:generate_content).and_return(api_response)
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'generates complete response with tokens', :aggregate_failures do
      result = client.generate(data:)

      expect(result).to be_a(LlmConductor::Response)
      expect(result.output).to eq('Gemini response')
      expect(result.input_tokens).to eq(3)
      expect(result.output_tokens).to eq(3)
      expect(result.metadata[:prompt]).to include('TestCorp')
    end
  end
end
