# frozen_string_literal: true

require 'llm_conductor'

# Configure Groq
LlmConductor.configure do |config|
  config.groq(api_key: ENV['GROQ_API_KEY'])
end

# Example 1: Using Groq with automatic model detection
puts '=== Example 1: Automatic model detection ==='
client = LlmConductor::ClientFactory.build(
  model: 'llama-3.1-70b-versatile',
  type: :summarize_text
)

data = {
  text: 'Groq is a cloud-based AI platform that provides fast inference for large language models. ' \
        'It offers various models including Llama, Mixtral, Gemma, and Qwen models with ' \
        'optimized performance for production use cases.'
}

response = client.generate(data:)
puts "Model: #{response.model}"
puts "Vendor: #{response.metadata[:vendor]}"
puts "Input tokens: #{response.input_tokens}"
puts "Output tokens: #{response.output_tokens}"
puts "Summary: #{response.output}"
puts

# Example 2: Using Groq with explicit vendor specification
puts '=== Example 2: Explicit vendor specification ==='
client = LlmConductor::ClientFactory.build(
  model: 'mixtral-8x7b-32768',
  type: :summarize_text,
  vendor: :groq
)

response = client.generate(data:)
puts "Model: #{response.model}"
puts "Vendor: #{response.metadata[:vendor]}"
puts "Summary: #{response.output}"
puts

# Example 3: Using Groq with simple generation
puts '=== Example 3: Simple generation ==='
client = LlmConductor::ClientFactory.build(
  model: 'gemma-7b-it',
  type: :summarize_text,
  vendor: :groq
)

response = client.generate_simple(prompt: 'Explain what Groq is in one sentence.')
puts "Model: #{response.model}"
puts "Response: #{response.output}"
puts

# Example 4: Using different Groq models
puts '=== Example 4: Different Groq models ==='
models = [
  'llama-3.1-70b-versatile',
  'mixtral-8x7b-32768',
  'gemma-7b-it',
  'qwen-2.5-72b-instruct'
]

models.each do |model|
  client = LlmConductor::ClientFactory.build(
    model:,
    type: :summarize_text,
    vendor: :groq
  )

  response = client.generate_simple(prompt: 'What is artificial intelligence?')
  puts "#{model}: #{response.output[0..100]}..."
  puts
end
