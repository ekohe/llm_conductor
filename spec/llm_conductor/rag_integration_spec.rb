# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'LlmConductor RAG Integration' do
  let(:mock_client) { instance_double(LlmConductor::Clients::GptClient) }
  let(:retrieved_context) do
    {
      title: 'Quantum Computing Basics',
      content: 'Quantum computing uses quantum mechanics principles...',
      source: 'Science Journal 2024',
      relevance_score: 0.95
    }
  end

  before do
    allow(LlmConductor).to receive(:build_client).and_return(mock_client)
    allow(LlmConductor::Clients::GptClient).to receive(:new).and_return(mock_client)
  end

  describe 'Template-based RAG with structured data' do
    it 'supports legacy template approach for RAG' do
      expected_result = {
        input: 'Generated prompt with context',
        output: 'Based on the context provided, quantum computing...',
        input_tokens: 50,
        output_tokens: 100
      }

      allow(mock_client).to receive(:generate).and_return(expected_result)

      result = LlmConductor.generate(
        model: 'gpt-3.5-turbo',
        type: :custom,
        data: {
          template: 'Context: {{context}}\nQuestion: {{question}}',
          context: retrieved_context[:content],
          question: 'What is quantum computing?'
        }
      )

      expect(result[:output]).to include('quantum computing')
      expect(result[:input_tokens]).to eq(50)
      expect(result[:output_tokens]).to eq(100)
    end

    it 'passes structured RAG data to client correctly' do
      allow(mock_client).to receive(:generate).and_return({
                                                            input: 'prompt',
                                                            output: 'response',
                                                            input_tokens: 10,
                                                            output_tokens: 20
                                                          })

      rag_data = {
        template: 'Based on {{context}} answer {{question}}',
        context: 'Retrieved knowledge base content...',
        question: 'User question here'
      }

      LlmConductor.generate(
        model: 'gpt-4',
        type: :custom,
        data: rag_data
      )

      expect(mock_client).to have_received(:generate).with(data: rag_data)
    end
  end

  describe 'Simple prompt RAG with embedded context' do
    let(:mock_response) do
      LlmConductor::Response.new(
        output: 'RAG response with context integration...',
        model: 'gpt-3.5-turbo',
        input_tokens: 75,
        output_tokens: 125,
        metadata: { vendor: :gpt, timestamp: Time.zone.now.iso8601 }
      )
    end

    before do
      allow(mock_client).to receive(:generate_simple).and_return(mock_response)
    end

    it 'supports simple prompt approach for RAG' do
      rag_prompt = <<~PROMPT
        Context: #{retrieved_context[:content]}
        Source: #{retrieved_context[:source]}

        Question: What are quantum computing applications?

        Answer based on the context above:
      PROMPT

      response = LlmConductor.generate(
        model: 'gpt-3.5-turbo',
        prompt: rag_prompt
      )

      expect(response).to be_a(LlmConductor::Response)
      expect(response.output).to include('RAG response')
      expect(response.total_tokens).to eq(200)
      expect(response.success?).to be true
    end

    it 'handles multi-document RAG scenarios' do
      contexts = [
        'Context 1: Quantum mechanics principles...',
        'Context 2: Current quantum computing limitations...',
        'Context 3: Future quantum applications...'
      ]

      multi_doc_prompt = "Multiple contexts:\n#{contexts.join("\n")}\n\nQuestion: Summarize quantum computing."

      response = LlmConductor.generate(prompt: multi_doc_prompt)

      expect(mock_client).to have_received(:generate_simple).with(prompt: multi_doc_prompt)
      expect(response.success?).to be true
    end

    it 'provides cost estimation for RAG queries' do
      response = LlmConductor.generate(
        model: 'gpt-3.5-turbo',
        prompt: 'RAG prompt with context...'
      )

      expect(response.estimated_cost).to be_a(Float)
      expect(response.estimated_cost).to be_positive
    end
  end

  describe 'RAG error handling' do
    it 'handles RAG failures gracefully in simple mode' do
      error_response = LlmConductor::Response.new(
        output: nil,
        model: 'gpt-3.5-turbo',
        metadata: { error: 'Context too long', error_class: 'ArgumentError' }
      )

      allow(mock_client).to receive(:generate_simple).and_return(error_response)

      response = LlmConductor.generate(
        prompt: 'Very long RAG context that exceeds limits...'
      )

      expect(response.success?).to be false
      expect(response.metadata[:error]).to eq('Context too long')
    end

    it 'handles template-based RAG errors' do
      allow(mock_client).to receive(:generate).and_raise(StandardError.new('Template error'))

      expect do
        LlmConductor.generate(
          type: :custom,
          data: { invalid: 'template structure' }
        )
      end.to raise_error(StandardError, 'Template error')
    end
  end

  describe 'RAG performance considerations' do
    it 'tracks token usage for cost optimization in RAG scenarios' do
      large_context = 'Large retrieved context...' * 100 # Simulate large context

      mock_response = LlmConductor::Response.new(
        output: 'Response based on large context',
        model: 'gpt-3.5-turbo',
        input_tokens: 500, # Large input due to context
        output_tokens: 150,
        metadata: { vendor: :gpt }
      )

      allow(mock_client).to receive(:generate_simple).and_return(mock_response)

      response = LlmConductor.generate(
        prompt: "Context: #{large_context}\nQuestion: Summarize this?"
      )

      expect(response.input_tokens).to eq(500)
      expect(response.output_tokens).to eq(150)
      expect(response.total_tokens).to eq(650)
      expect(response.estimated_cost).to be_positive
    end
  end
end
