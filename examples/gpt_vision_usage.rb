#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/llm_conductor'

# This example demonstrates using GPT-4o vision capabilities
# Set your OpenAI API key: export OPENAI_API_KEY='your-key-here'

puts '=' * 80
puts 'GPT-4o Vision Usage Examples'
puts '=' * 80
puts

# Check for API key
api_key = ENV['OPENAI_API_KEY']
if api_key.nil? || api_key.empty?
  puts 'ERROR: OPENAI_API_KEY environment variable is not set!'
  puts
  puts 'Please set your OpenAI API key:'
  puts '  export OPENAI_API_KEY="your-key-here"'
  puts
  puts 'You can get an API key from: https://platform.openai.com/api-keys'
  exit 1
end

# Configure the client
LlmConductor.configure do |config|
  config.openai(api_key:)
end

# Example 1: Single Image Analysis
puts "\n1. Single Image Analysis"
puts '-' * 80

response = LlmConductor.generate(
  model: 'gpt-4o',
  vendor: :openai,
  prompt: {
    text: 'What is in this image? Please describe it in detail.',
    images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  }
)

puts "Response: #{response.output}"
puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"

# Example 2: Multiple Images Comparison
puts "\n2. Multiple Images Comparison"
puts '-' * 80

response = LlmConductor.generate(
  model: 'gpt-4o',
  vendor: :openai,
  prompt: {
    text: 'Compare these two images. What are the main differences?',
    images: [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/1024px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Placeholder_view_vector.svg/1024px-Placeholder_view_vector.svg.png'
    ]
  }
)

puts "Response: #{response.output}"
puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"

# Example 3: Image with Detail Level - High Resolution
puts "\n3. Image with Detail Level - High Resolution"
puts '-' * 80

response = LlmConductor.generate(
  model: 'gpt-4o',
  vendor: :openai,
  prompt: {
    text: 'Analyze this high-resolution image in detail. What are all the elements you can see?',
    images: [
      { url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg', detail: 'high' }
    ]
  }
)

puts "Response: #{response.output}"
puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"

# Example 4: Image with Detail Level - Low (Faster, Cheaper)
puts "\n4. Image with Detail Level - Low (Faster, Cheaper)"
puts '-' * 80

response = LlmConductor.generate(
  model: 'gpt-4o',
  vendor: :openai,
  prompt: {
    text: 'Give me a quick description of this image.',
    images: [
      { url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/1024px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg', detail: 'low' }
    ]
  }
)

puts "Response: #{response.output}"
puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"

# Example 5: Raw Format (Advanced)
puts "\n5. Raw Format (Advanced)"
puts '-' * 80

response = LlmConductor.generate(
  model: 'gpt-4o',
  vendor: :openai,
  prompt: [
    { type: 'text', text: 'What is in this image?' },
    { type: 'image_url',
      image_url: { url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/1024px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg' } },
    { type: 'text', text: 'Describe the weather conditions.' }
  ]
)

puts "Response: #{response.output}"
puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"

# Example 6: Text-Only Request (Backward Compatible)
puts "\n6. Text-Only Request (Backward Compatible)"
puts '-' * 80

response = LlmConductor.generate(
  model: 'gpt-4o',
  vendor: :openai,
  prompt: 'What is the capital of France?'
)

puts "Response: #{response.output}"
puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"

# Example 7: Multiple Images with Mixed Detail Levels
puts "\n7. Multiple Images with Mixed Detail Levels"
puts '-' * 80

response = LlmConductor.generate(
  model: 'gpt-4o',
  vendor: :openai,
  prompt: {
    text: 'Compare these images at different detail levels.',
    images: [
      {
        url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/1024px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg', detail: 'high'
      },
      { url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Placeholder_view_vector.svg/1024px-Placeholder_view_vector.svg.png', detail: 'low' }
    ]
  }
)

puts "Response: #{response.output}"
puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"

puts "\n#{'=' * 80}"
puts 'All examples completed successfully!'
puts '=' * 80
