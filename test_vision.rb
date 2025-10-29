#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick test script for OpenRouter vision
require_relative 'lib/llm_conductor'

# Configure
LlmConductor.configure do |config|
  config.openrouter(
    api_key: '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'
  )
  # Enable logging to see retry attempts
  config.logger = Logger.new($stdout)
  config.logger.level = Logger::INFO
end

# Test 1: Simple text
puts "\n=== Text-only test ==="
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: 'Say hello in one sentence'
)
puts "Response: #{response.output}"
puts "Success: #{response.success?}"
puts "Tokens: #{response.total_tokens}"

# Test 2: Vision with single image
puts "\n=== Vision test (single image) ==="
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: {
    text: 'What do you see in this image? Describe it briefly.',
    images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/800px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  }
)
puts "Response: #{response.output}"
puts "Success: #{response.success?}"
unless response.success?
  puts "Error: #{response.metadata[:error]}"
  puts "Error class: #{response.metadata[:error_class]}"
  puts "Full metadata: #{response.metadata.inspect}"
end

# Test 3: Multiple images
puts "\n=== Vision test (multiple images) ==="
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: {
    text: 'Compare these two images. What are the main differences?',
    images: [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/800px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Placeholder_view_vector.svg/400px-Placeholder_view_vector.svg.png'
    ]
  }
)
puts "Response: #{response.output}"
puts "Success: #{response.success?}"
unless response.success?
  puts "Error: #{response.metadata[:error]}"
  puts "Error class: #{response.metadata[:error_class]}"
  puts "Full metadata: #{response.metadata.inspect}"
end

puts "\n=== All tests completed ==="
