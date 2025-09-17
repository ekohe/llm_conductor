#!/usr/bin/env ruby
# frozen_string_literal: true

# Example of simple LlmConductor usage
require_relative '../lib/llm_conductor'

# Configure the gem (optional - will use environment variables by default)
LlmConductor.configure do |config|
  config.default_model = 'gpt-3.5-turbo'
  config.openai(api_key: ENV['OPENAI_API_KEY'])
end

# Simple text generation
response = LlmConductor.generate(
  model: 'gpt-3.5-turbo',
  prompt: 'Explain quantum computing in simple terms'
)

puts response.output
puts "Tokens used: #{response.total_tokens}"
puts "Cost: $#{response.estimated_cost}" if response.estimated_cost

# Example with default model (from configuration)
response2 = LlmConductor.generate(
  prompt: 'What are the benefits of renewable energy?'
)

puts "\n--- Second Example ---"
puts response2.output
puts "Input tokens: #{response2.input_tokens}"
puts "Output tokens: #{response2.output_tokens}"
puts "Success: #{response2.success?}"

# Example with error handling
begin
  response3 = LlmConductor.generate(
    model: 'invalid-model',
    prompt: 'This should fail'
  )

  if response3.success?
    puts response3.output
  else
    puts "Error: #{response3.metadata[:error]}"
  end
rescue StandardError => e
  puts "Exception: #{e.message}"
end
