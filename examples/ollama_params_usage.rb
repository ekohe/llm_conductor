#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating how to use custom parameters with Ollama client
require_relative '../lib/llm_conductor'

# Configure Ollama (optional if using default localhost)
LlmConductor.configure do |config|
  config.ollama(base_url: ENV.fetch('OLLAMA_BASE_URL', 'http://localhost:11434'))
end

puts '=== Example 1: Using temperature parameter ==='
# Generate with custom temperature
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Write a creative story about a robot learning to paint.',
  vendor: :ollama,
  params: { temperature: 0.9 }
)

puts response.output
puts "Tokens used: #{response.total_tokens}"
puts "\n"

puts '=== Example 2: Using multiple parameters ==='
# Generate with multiple custom parameters
response2 = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Explain the concept of artificial intelligence in simple terms.',
  vendor: :ollama,
  params: {
    temperature: 0.7,
    top_p: 0.9,
    top_k: 40,
    num_predict: 200 # Max tokens to generate
  }
)

puts response2.output
puts "Input tokens: #{response2.input_tokens}"
puts "Output tokens: #{response2.output_tokens}"
puts "\n"

puts '=== Example 3: Using params with build_client ==='
# You can also use params when building a client directly
client = LlmConductor.build_client(
  model: 'llama2',
  type: :custom,
  vendor: :ollama,
  params: {
    temperature: 0.3, # Lower temperature for more focused output
    repeat_penalty: 1.1
  }
)

response3 = client.generate_simple(
  prompt: 'List 5 benefits of regular exercise.'
)

puts response3.output
puts "Success: #{response3.success?}"
puts "\n"

puts '=== Example 4: Low temperature for deterministic output ==='
# Use low temperature for more deterministic results
response4 = LlmConductor.generate(
  model: 'llama2',
  prompt: 'What is 2 + 2?',
  vendor: :ollama,
  params: { temperature: 0.0 }
)

puts response4.output
puts "\n"

puts '=== Available Ollama Parameters ==='
puts <<~PARAMS
  Common parameters you can use with Ollama:

  - temperature: Controls randomness (0.0 to 2.0, default: 0.8)
    Lower = more focused and deterministic
    Higher = more random and creative

  - top_p: Nucleus sampling (0.0 to 1.0, default: 0.9)
    Controls diversity via nucleus sampling

  - top_k: Top-k sampling (default: 40)
    Limits vocabulary to top K tokens

  - num_predict: Maximum tokens to generate (default: 128)

  - repeat_penalty: Penalizes repetition (default: 1.1)

  - seed: Random seed for reproducibility

  - stop: Stop sequences (array of strings)

  For more parameters, see: https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values
PARAMS
