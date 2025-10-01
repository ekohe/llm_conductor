# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe LlmConductor::Clients::BaseClient do
  let(:model) { 'test-model' }
  let(:type) { :summarize_description }
  let(:client) { described_class.new(model:, type:) }

  describe '#initialize' do
    it 'sets model and type attributes' do
      expect(client.model).to eq(model)
      expect(client.type).to eq(type)
    end
  end

  describe '#generate' do
    let(:data) { { name: 'TestCorp', description: 'A test company' } }
    let(:prompt) { 'Generated prompt content' }
    let(:output) { 'Generated output content' }

    before do
      allow(client).to receive(:build_prompt).with(data).and_return(prompt)
      allow(client).to receive(:generate_content).with(prompt).and_return(output)
      allow(client).to receive(:calculate_tokens).with(prompt).and_return(100)
      allow(client).to receive(:calculate_tokens).with(output).and_return(50)
      allow(client).to receive(:configuration).and_return(LlmConductor.configuration)
      allow(LlmConductor.configuration).to receive(:logger).and_return(nil)
    end

    it 'returns a Response object with output and token counts' do
      result = client.generate(data:)

      expect(result).to be_a(LlmConductor::Response)
      expect(result.output).to eq(output)
      expect(result.input_tokens).to eq(100)
      expect(result.output_tokens).to eq(50)
      expect(result.metadata[:prompt]).to eq(prompt)
    end

    it 'calls the correct private methods in sequence' do
      client.generate(data:)

      expect(client).to have_received(:build_prompt).with(data)
      expect(client).to have_received(:generate_content).with(prompt)
      expect(client).to have_received(:calculate_tokens).with(prompt)
      expect(client).to have_received(:calculate_tokens).with(output)
    end
  end

  describe '#build_prompt (private)' do
    let(:data) { { test: 'data' } }
    let(:expected_prompt) { 'Generated prompt from method' }

    before do
      allow(client).to receive(:"prompt_#{type}").with(data).and_return(expected_prompt)
    end

    it 'calls the appropriate prompt method based on type' do
      result = client.send(:build_prompt, data)

      expect(client).to have_received(:"prompt_#{type}").with(data)
      expect(result).to eq(expected_prompt)
    end
  end

  describe '#generate_content (private)' do
    it 'raises NotImplementedError in base class' do
      expect { client.send(:generate_content, 'test prompt') }.to raise_error(NotImplementedError)
    end
  end

  describe '#calculate_tokens (private)' do
    let(:content) { 'test content for token calculation' }
    let(:mock_encoder) { double('encoder') }
    let(:encoded_tokens) { %w[test content for token calculation] }

    before do
      allow(client).to receive(:encoder).and_return(mock_encoder)
      allow(mock_encoder).to receive(:encode).with(content).and_return(encoded_tokens)
    end

    it 'returns the length of encoded tokens' do
      result = client.send(:calculate_tokens, content)

      expect(result).to eq(5)
      expect(mock_encoder).to have_received(:encode).with(content)
    end
  end

  describe '#encoder (private)' do
    let(:mock_encoder) { double('tiktoken_encoder') }

    before do
      allow(Tiktoken).to receive(:get_encoding).with('cl100k_base').and_return(mock_encoder)
    end

    it 'returns a tiktoken encoder instance' do
      result = client.send(:encoder)

      expect(result).to eq(mock_encoder)
      expect(Tiktoken).to have_received(:get_encoding).with('cl100k_base')
    end

    it 'memoizes the encoder instance' do
      encoder1 = client.send(:encoder)
      encoder2 = client.send(:encoder)

      expect(encoder1).to be(encoder2)
      expect(Tiktoken).to have_received(:get_encoding).once
    end
  end

  describe '#client (private)' do
    it 'raises NotImplementedError in base class' do
      expect { client.send(:client) }.to raise_error(NotImplementedError)
    end
  end

  describe 'logging integration' do
    let(:string_io) { StringIO.new }
    let(:logger) { Logger.new(string_io) }
    let(:data) { { name: 'TestCorp' } }
    let(:prompt) { 'Generated prompt content' }
    let(:output) { 'Generated output content' }

    before do
      # Configure logger
      allow(LlmConductor.configuration).to receive_messages(logger:)
      logger.level = Logger::DEBUG

      # Mock client methods
      allow(client).to receive_messages(
        build_prompt: prompt,
        generate_content: output,
        vendor_name: :test,
        configuration: LlmConductor.configuration
      )
      allow(client).to receive(:calculate_tokens).and_return(100)
    end

    context 'when logger is configured' do
      it 'logs debug information during generate' do
        client.generate(data:)

        log_output = string_io.string
        expect(log_output).to include('DEBUG')
        expect(log_output).to include('Vendor: test')
        expect(log_output).to include('Model: test-model')
        expect(log_output).to include('Output_tokens: 100')
        expect(log_output).to include('Input_tokens: 100')
      end

      it 'logs debug information during generate_simple' do
        client.generate_simple(prompt: 'Test prompt')

        log_output = string_io.string
        expect(log_output).to include('DEBUG')
        expect(log_output).to include('Vendor: test')
        expect(log_output).to include('Model: test-model')
        expect(log_output).to include('Output_tokens: 100')
        expect(log_output).to include('Input_tokens: 100')
      end
    end

    context 'when logger is not configured' do
      before do
        allow(LlmConductor.configuration).to receive(:logger).and_return(nil)
      end

      it 'does not raise error when logger is nil' do
        expect { client.generate(data:) }.not_to raise_error
        expect { client.generate_simple(prompt: 'Test') }.not_to raise_error
      end
    end

    context 'when log level blocks debug messages' do
      before do
        logger.level = Logger::ERROR
      end

      it 'does not log debug messages' do
        client.generate(data:)
        expect(string_io.string).to be_empty
      end
    end
  end
end
