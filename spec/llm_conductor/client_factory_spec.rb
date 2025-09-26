# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe LlmConductor::ClientFactory do
  describe '.build' do
    let(:model) { 'test-model' }
    let(:type) { :summarize_description }

    # Reset logger before each test to ensure clean state
    before do
      LlmConductor::Logger.instance_variable_set(:@instance, nil)
    end

    after do
      LlmConductor::Logger.instance_variable_set(:@instance, nil)
    end

    context 'when vendor is :anthropic' do
      it 'returns an AnthropicClient instance' do
        client = described_class.build(model:, type:, vendor: :anthropic)
        expect(client).to be_a(LlmConductor::Clients::AnthropicClient)
        expect(client.model).to eq(model)
        expect(client.type).to eq(type)
      end
    end

    context 'when vendor is :claude' do
      it 'returns an AnthropicClient instance' do
        client = described_class.build(model:, type:, vendor: :claude)
        expect(client).to be_a(LlmConductor::Clients::AnthropicClient)
        expect(client.model).to eq(model)
        expect(client.type).to eq(type)
      end
    end

    context 'when vendor is :openrouter' do
      it 'returns an OpenrouterClient instance' do
        client = described_class.build(model:, type:, vendor: :openrouter)
        expect(client).to be_a(LlmConductor::Clients::OpenrouterClient)
        expect(client.model).to eq(model)
        expect(client.type).to eq(type)
      end
    end

    context 'when vendor is :gemini' do
      it 'returns a GeminiClient instance' do
        client = described_class.build(model:, type:, vendor: :gemini)
        expect(client).to be_a(LlmConductor::Clients::GeminiClient)
        expect(client.model).to eq(model)
        expect(client.type).to eq(type)
      end
    end

    context 'when vendor is :google' do
      it 'returns a GeminiClient instance' do
        client = described_class.build(model:, type:, vendor: :google)
        expect(client).to be_a(LlmConductor::Clients::GeminiClient)
        expect(client.model).to eq(model)
        expect(client.type).to eq(type)
      end
    end

    context 'when vendor is not specified' do
      context 'and model starts with "claude"' do
        let(:model) { 'claude-3-5-sonnet-20241022' }

        it 'returns an AnthropicClient instance' do
          client = described_class.build(model:, type:)
          expect(client).to be_a(LlmConductor::Clients::AnthropicClient)
          expect(client.model).to eq(model)
          expect(client.type).to eq(type)
        end
      end

      context 'and model starts with "gpt"' do
        let(:model) { 'gpt-4o-mini' }

        it 'returns a GptClient instance' do
          client = described_class.build(model:, type:)
          expect(client).to be_a(LlmConductor::Clients::GptClient)
          expect(client.model).to eq(model)
          expect(client.type).to eq(type)
        end
      end

      context 'and model starts with "gemini"' do
        let(:model) { 'gemini-2.5-flash' }

        it 'returns a GeminiClient instance' do
          client = described_class.build(model:, type:)
          expect(client).to be_a(LlmConductor::Clients::GeminiClient)
          expect(client.model).to eq(model)
          expect(client.type).to eq(type)
        end
      end

      context 'and model does not start with "gpt", "claude", or "gemini"' do
        let(:model) { 'llama2' }

        it 'returns an OllamaClient instance' do
          client = described_class.build(model:, type:)
          expect(client).to be_a(LlmConductor::Clients::OllamaClient)
          expect(client.model).to eq(model)
          expect(client.type).to eq(type)
        end
      end
    end

    context 'when vendor is explicitly set to something else' do
      let(:model) { 'gpt-4o-mini' }

      it 'still uses model detection for nil vendor' do
        client = described_class.build(model:, type:, vendor: nil)
        expect(client).to be_a(LlmConductor::Clients::GptClient)
      end
    end

    context 'when vendor is unsupported' do
      it 'raises an ArgumentError' do
        expect do
          described_class.build(model:, type:, vendor: :unsupported)
        end.to raise_error(ArgumentError,
                           'Unsupported vendor: unsupported. ' \
                           'Supported vendors: anthropic, openai, openrouter, ollama, gemini')
      end
    end
  end

  describe 'logging integration' do
    let(:model) { 'gpt-4o-mini' }
    let(:type) { :summarize_description }
    let(:vendor) { :openai }
    let(:string_io) { StringIO.new }

    context 'when log level allows info messages' do
      before do
        # Configure logger to write to StringIO for testing
        allow(LlmConductor.configuration).to receive(:log_level).and_return(:info)
        logger_instance = ::Logger.new(string_io)
        logger_instance.level = ::Logger::INFO
        allow(LlmConductor::Logger).to receive(:instance).and_return(logger_instance)
      end

      it 'logs client creation information' do
        described_class.build(model:, type:, vendor:)

        log_output = string_io.string
        expect(log_output).to include('INFO')
        expect(log_output).to include("Vendor: #{vendor}")
        expect(log_output).to include("Model: #{model}")
        expect(log_output).to include("Type: #{type}")
      end

      it 'logs with auto-detected vendor' do
        described_class.build(model: 'claude-3-5-sonnet-20241022', type:)

        log_output = string_io.string
        expect(log_output).to include('Vendor: anthropic')
        expect(log_output).to include('Model: claude-3-5-sonnet-20241022')
      end
    end

    context 'when log level blocks info messages' do
      before do
        # Set log level to error (higher than info)
        allow(LlmConductor.configuration).to receive(:log_level).and_return(:error)
        error_logger = ::Logger.new(string_io)
        error_logger.level = ::Logger::ERROR
        allow(LlmConductor::Logger).to receive(:instance).and_return(error_logger)
      end

      it 'does not log info messages' do
        described_class.build(model:, type:, vendor:)

        expect(string_io.string).to be_empty
      end
    end
  end
end
