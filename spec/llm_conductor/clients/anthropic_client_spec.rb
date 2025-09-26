# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Clients::AnthropicClient do
  let(:model) { 'claude-3-5-sonnet-20241022' }
  let(:type) { :summarize_text }
  let(:client) { described_class.new(model:, type:) }

  before do
    LlmConductor.configuration.anthropic_api_key = 'test_api_key'
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
    let(:prompt) { 'Test prompt for Claude' }
    let(:mock_anthropic_client) { double('Anthropic::Client') }
    let(:mock_response) { double('response', content: [double('content', text: 'Generated response from Claude')]) }

    before do
      allow(client).to receive(:client).and_return(mock_anthropic_client)
      allow(mock_anthropic_client).to receive(:messages).and_return(double('messages', create: mock_response))
    end

    it 'calls Anthropic messages API with correct parameters' do
      client.send(:generate_content, prompt)

      expect(mock_anthropic_client).to have_received(:messages)
      expect(mock_anthropic_client.messages).to have_received(:create).with(
        model:,
        max_tokens: 4096,
        messages: [{ role: 'user', content: prompt }]
      )
    end

    it 'extracts and returns the content from API response' do
      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from Claude')
    end

    it 'handles API response structure correctly' do
      allow(mock_anthropic_client).to receive(:messages).and_return(double('messages', create: mock_response))

      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from Claude')
    end

    it 'handles Anthropic API errors' do
      messages_mock = double('messages')
      allow(messages_mock).to receive(:create).and_raise(Anthropic::Errors::APIError.new(url: 'https://api.anthropic.com'))
      allow(mock_anthropic_client).to receive(:messages).and_return(messages_mock)

      expect { client.send(:generate_content, prompt) }.to raise_error(StandardError, /Anthropic API error:/)
    end
  end

  describe '#client (private)' do
    let(:mock_anthropic_client) { double('Anthropic::Client') }

    before do
      allow(Anthropic::Client).to receive(:new).and_return(mock_anthropic_client)
    end

    it 'creates Anthropic client with API key' do
      client.send(:client)

      expect(Anthropic::Client).to have_received(:new).with(
        api_key: 'test_api_key'
      )
    end

    it 'memoizes the client instance' do
      client1 = client.send(:client)
      client2 = client.send(:client)

      expect(client1).to be(client2)
      expect(Anthropic::Client).to have_received(:new).once
    end

    it 'uses configuration for API key' do
      LlmConductor.configuration.anthropic_api_key = 'different_key'
      allow(Anthropic::Client).to receive(:new).and_return(mock_anthropic_client)

      client.send(:client)

      expect(Anthropic::Client).to have_received(:new).with(
        api_key: 'different_key'
      )
    end
  end

  describe 'integration with base class' do
    let(:data) { { text: 'TestCorp is an AI company specializing in machine learning solutions.' } }
    let(:mock_anthropic_client) { double('Anthropic::Client') }
    let(:mock_response) { double('response', content: [double('content', text: 'Claude response')]) }
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2 token3]) }

    before do
      allow(Anthropic::Client).to receive(:new).and_return(mock_anthropic_client)
      allow(mock_anthropic_client).to receive(:messages).and_return(double('messages', create: mock_response))
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'generates complete response with tokens', :aggregate_failures do
      result = client.generate(data:)

      expect(result).to be_a(LlmConductor::Response)
      expect(result.output).to eq('Claude response')
      expect(result.input_tokens).to eq(3)
      expect(result.output_tokens).to eq(3)
      expect(result.metadata[:prompt]).to include('TestCorp')
    end
  end
end
