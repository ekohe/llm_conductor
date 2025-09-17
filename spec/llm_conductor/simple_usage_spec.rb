# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'LlmConductor Simple Usage' do
  let(:mock_client) { instance_double(LlmConductor::Clients::GptClient) }
  let(:mock_response) do
    LlmConductor::Response.new(
      output: 'Quantum computing uses quantum mechanics principles...',
      model: 'gpt-3.5-turbo',
      input_tokens: 10,
      output_tokens: 20,
      metadata: { vendor: :gpt, timestamp: Time.zone.now.iso8601 }
    )
  end

  before do
    allow(LlmConductor::Clients::GptClient).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:generate_simple).and_return(mock_response)
  end

  describe '.generate with simple prompt' do
    it 'generates content with direct prompt' do
      response = LlmConductor.generate(
        model: 'gpt-3.5-turbo',
        prompt: 'Explain quantum computing'
      )

      expect(response).to be_a(LlmConductor::Response)
      expect(response.output).to eq('Quantum computing uses quantum mechanics principles...')
      expect(response.total_tokens).to eq(30)
      expect(response.model).to eq('gpt-3.5-turbo')
    end

    it 'uses default model when not specified' do
      allow(LlmConductor.configuration).to receive(:default_model).and_return('gpt-4')

      LlmConductor.generate(prompt: 'Hello world')

      expect(LlmConductor::Clients::GptClient).to have_received(:new).with(model: 'gpt-4', type: :direct)
    end

    it 'calculates estimated cost for supported models' do
      response = LlmConductor.generate(
        model: 'gpt-3.5-turbo',
        prompt: 'Test prompt'
      )

      cost = response.estimated_cost
      expect(cost).to be_a(Float)
      expect(cost).to be_positive
    end

    it 'returns nil cost for unsupported models' do
      mock_response_ollama = LlmConductor::Response.new(
        output: 'Response from Ollama',
        model: 'llama2',
        input_tokens: 10,
        output_tokens: 20
      )

      allow(mock_client).to receive(:generate_simple).and_return(mock_response_ollama)

      response = LlmConductor.generate(
        model: 'llama2',
        prompt: 'Test prompt',
        vendor: :ollama
      )

      expect(response.estimated_cost).to be_nil
    end

    it 'handles errors gracefully' do
      error_response = LlmConductor::Response.new(
        output: nil,
        model: 'gpt-3.5-turbo',
        metadata: { error: 'API error', error_class: 'StandardError' }
      )

      allow(mock_client).to receive(:generate_simple).and_return(error_response)

      response = LlmConductor.generate(
        model: 'gpt-3.5-turbo',
        prompt: 'This will fail'
      )

      expect(response.success?).to be false
      expect(response.metadata[:error]).to eq('API error')
    end
  end

  describe 'Response object' do
    it 'provides success check' do
      successful_response = LlmConductor::Response.new(output: 'Good response', model: 'gpt-4')
      failed_response = LlmConductor::Response.new(output: nil, model: 'gpt-4')
      empty_response = LlmConductor::Response.new(output: '', model: 'gpt-4')

      expect(successful_response.success?).to be true
      expect(failed_response.success?).to be false
      expect(empty_response.success?).to be false
    end

    it 'includes cost in metadata_with_cost when available' do
      response = LlmConductor::Response.new(
        output: 'Test',
        model: 'gpt-3.5-turbo',
        input_tokens: 10,
        output_tokens: 20,
        metadata: { vendor: :gpt }
      )

      metadata = response.metadata_with_cost
      expect(metadata[:cost]).to be_a(Float)
      expect(metadata[:vendor]).to eq(:gpt)
    end
  end
end
