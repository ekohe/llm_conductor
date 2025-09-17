#!/usr/bin/env ruby
# frozen_string_literal: true

# Example of RAG (Retrieval-Augmented Generation) usage with LlmConductor
require_relative '../lib/llm_conductor'

# Configure the gem
LlmConductor.configure do |config|
  config.default_model = 'gpt-3.5-turbo'
  config.openai(api_key: ENV['OPENAI_API_KEY'])
end

# RAG Example 1: Using template-based generation with structured data
puts '=== RAG Example 1: Template-based with structured data ==='

# Simulate retrieved context from your knowledge base
retrieved_context = {
  title: 'Quantum Computing Overview',
  content: 'Quantum computing leverages quantum mechanical phenomena like superposition and entanglement...',
  source: 'Scientific Journal of Computing, 2024',
  relevance_score: 0.95
}

# Use the legacy template approach for structured RAG
result = LlmConductor.generate(
  model: 'gpt-3.5-turbo',
  type: :custom,
  data: {
    template: "Based on the following context: {{context}}\n\nAnswer this question: {{question}}",
    context: "#{retrieved_context[:title]}: #{retrieved_context[:content]} (Source: #{retrieved_context[:source]})",
    question: 'What are the key principles of quantum computing?'
  }
)

puts 'Template-based RAG Response:'
puts result[:output] if result[:output]
puts "Tokens: #{result[:input_tokens]} + #{result[:output_tokens]} = #{result[:input_tokens] + result[:output_tokens]}"
puts

# RAG Example 2: Using simple prompt generation with embedded context
puts '=== RAG Example 2: Simple prompt with embedded context ==='

# Build your RAG prompt manually for maximum control
rag_prompt = <<~PROMPT
  You are an expert assistant. Use the following context to answer the question accurately.

  Context:
  #{retrieved_context[:content]}
  Source: #{retrieved_context[:source]}

  Question: What are the practical applications of quantum computing?

  Please provide a comprehensive answer based on the context above.
PROMPT

# Use the new simple API
response = LlmConductor.generate(
  model: 'gpt-3.5-turbo',
  prompt: rag_prompt
)

puts 'Simple RAG Response:'
puts response.output if response.success?
puts "Tokens used: #{response.total_tokens}"
puts "Estimated cost: $#{response.estimated_cost}"
puts

# RAG Example 3: Multi-document RAG with multiple contexts
puts '=== RAG Example 3: Multi-document RAG ==='

contexts = [
  'Quantum computers use qubits that can exist in superposition states...',
  'Current quantum computers are limited by decoherence and error rates...',
  'Major companies like IBM, Google, and Microsoft are investing heavily in quantum research...'
]

multi_doc_prompt = <<~PROMPT
  Based on the following multiple sources, provide a comprehensive answer:

  #{contexts.map.with_index { |ctx, i| "Source #{i + 1}: #{ctx}" }.join("\n\n")}

  Question: What is the current state and future outlook of quantum computing?
PROMPT

response = LlmConductor.generate(prompt: multi_doc_prompt)

puts 'Multi-document RAG Response:'
puts response.output if response.success?
puts "Success: #{response.success?}"
puts

# RAG Example 4: Error handling in RAG scenarios
puts '=== RAG Example 4: Error handling ==='

begin
  response = LlmConductor.generate(
    model: 'invalid-model',
    prompt: 'This should fail gracefully'
  )

  if response.success?
    puts response.output
  else
    puts "RAG Error handled gracefully: #{response.metadata[:error]}"
  end
rescue StandardError => e
  puts "Exception in RAG: #{e.message}"
end
