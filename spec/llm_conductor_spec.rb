# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe LlmConductor do
  describe 'module constants' do
    it 'has a version number' do
      expect(described_class::VERSION).not_to be_nil
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it 'defines supported vendors' do
      expect(described_class::SUPPORTED_VENDORS).to match_array(%i[openai openrouter ollama anthropic gemini])
    end

    it 'defines supported prompt types' do
      expect(described_class::SUPPORTED_PROMPT_TYPES).to eq(%i[
                                                              extract_links
                                                              analyze_content
                                                              summarize_text
                                                              classify_content
                                                              custom
                                                            ])
    end
  end

  describe '.build_client' do
    let(:model) { 'gpt-4o-mini' }
    let(:type) { :summarize_text }

    it 'returns a BaseClient instance' do
      client = described_class.build_client(model:, type:)
      expect(client).to be_a(LlmConductor::Clients::BaseClient)
    end

    it 'delegates to ClientFactory.build' do
      allow(LlmConductor::ClientFactory).to receive(:build)

      described_class.build_client(model:, type:, vendor: :openai)

      expect(LlmConductor::ClientFactory).to have_received(:build).with(
        model:, type:, vendor: :openai
      )
    end

    it 'passes all parameters to ClientFactory' do
      allow(LlmConductor::ClientFactory).to receive(:build)

      described_class.build_client(model: 'custom-model', type: :custom, vendor: :openrouter)

      expect(LlmConductor::ClientFactory).to have_received(:build).with(
        model: 'custom-model', type: :custom, vendor: :openrouter
      )
    end
  end

  describe '.generate' do
    let(:model) { 'gpt-4o-mini' }
    let(:type) { :summarize_description }
    let(:data) { { name: 'TestCorp' } }
    let(:mock_client) { double('Client') }
    let(:expected_result) { { output: 'Generated content', input_tokens: 10, output_tokens: 5 } }

    before do
      allow(described_class).to receive(:build_client).and_return(mock_client)
      allow(mock_client).to receive(:generate).and_return(expected_result)
    end

    it 'builds a client and generates content' do
      result = described_class.generate(model:, type:, data:)

      expect(described_class).to have_received(:build_client).with(model:, type:, vendor: nil)
      expect(mock_client).to have_received(:generate).with(data:)
      expect(result).to eq(expected_result)
    end

    it 'passes vendor parameter when provided' do
      described_class.generate(model:, type:, data:, vendor: :openrouter)

      expect(described_class).to have_received(:build_client).with(
        model:, type:, vendor: :openrouter
      )
    end

    it 'returns the generated result directly' do
      result = described_class.generate(model:, type:, data:)

      expect(result).to eq(expected_result)
    end
  end

  describe 'error handling' do
    it 'defines Error as a StandardError subclass' do
      expect(described_class::Error).to be < StandardError
    end

    it 'allows raising custom errors' do
      expect { raise described_class::Error, 'Test error' }.to raise_error(
        described_class::Error, 'Test error'
      )
    end
  end
end
