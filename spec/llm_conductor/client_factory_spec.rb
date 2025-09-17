# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::ClientFactory do
  describe '.build' do
    let(:model) { 'test-model' }
    let(:type) { :summarize_description }

    context 'when vendor is :openrouter' do
      it 'returns an OpenrouterClient instance' do
        client = described_class.build(model:, type:, vendor: :openrouter)
        expect(client).to be_a(LlmConductor::Clients::OpenrouterClient)
        expect(client.model).to eq(model)
        expect(client.type).to eq(type)
      end
    end

    context 'when vendor is not specified' do
      context 'and model starts with "gpt"' do
        let(:model) { 'gpt-4o-mini' }

        it 'returns a GptClient instance' do
          client = described_class.build(model:, type:)
          expect(client).to be_a(LlmConductor::Clients::GptClient)
          expect(client.model).to eq(model)
          expect(client.type).to eq(type)
        end
      end

      context 'and model does not start with "gpt"' do
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
  end
end
