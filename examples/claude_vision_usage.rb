#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/llm_conductor'

# This example demonstrates using Claude Sonnet 4 vision capabilities
# Set your Anthropic API key: export ANTHROPIC_API_KEY='your-key-here'

puts '=' * 80
puts 'Claude Sonnet 4 Vision Usage Examples'
puts '=' * 80
puts

# Check for API key
api_key = ENV['ANTHROPIC_API_KEY']
if api_key.nil? || api_key.empty?
  puts 'ERROR: ANTHROPIC_API_KEY environment variable is not set!'
  puts
  puts 'Please set your Anthropic API key:'
  puts '  export ANTHROPIC_API_KEY="your-key-here"'
  puts
  puts 'You can get an API key from: https://console.anthropic.com/'
  exit 1
end

# Configure the client
LlmConductor.configure do |config|
  config.anthropic(api_key:)
end

# Example 1: Single Image Analysis
puts "\n1. Single Image Analysis"
puts '-' * 80

begin
  response = LlmConductor.generate(
    model: 'claude-sonnet-4-20250514',
    vendor: :anthropic,
    prompt: {
      text: 'What is in this image? Please describe it in detail.',
      images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
    }
  )

  puts "Response: #{response.output}"
  puts "Success: #{response.success?}"
  puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"
  puts "Metadata: #{response.metadata.inspect}" if response.metadata && !response.metadata.empty?
rescue StandardError => e
  puts "ERROR: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
end

# Example 2: Multiple Images Comparison
puts "\n2. Multiple Images Comparison"
puts '-' * 80

response = LlmConductor.generate(
  model: 'claude-sonnet-4-20250514',
  vendor: :anthropic,
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

# Example 3: Image with Specific Question
puts "\n3. Image with Specific Question"
puts '-' * 80

response = LlmConductor.generate(
  model: 'claude-sonnet-4-20250514',
  vendor: :anthropic,
  prompt: {
    text: 'Is there a wooden boardwalk visible in this image? If yes, describe its condition.',
    images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/1024px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  }
)

puts "Response: #{response.output}"
puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"

# Example 4: Raw Format (Advanced)
puts "\n4. Raw Format (Advanced)"
puts '-' * 80

response = LlmConductor.generate(
  model: 'claude-sonnet-4-20250514',
  vendor: :anthropic,
  prompt: [
    { type: 'image',
      source: { type: 'url',
                url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/1024px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg' } },
    { type: 'text', text: 'Describe the weather conditions in this image.' }
  ]
)

puts "Response: #{response.output}"
puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"

# Example 5: Text-Only Request (Backward Compatible)
puts "\n5. Text-Only Request (Backward Compatible)"
puts '-' * 80

response = LlmConductor.generate(
  model: 'claude-sonnet-4-20250514',
  vendor: :anthropic,
  prompt: 'What is the capital of France?'
)

puts "Response: #{response.output}"
puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"

# Example 6: Image Analysis with Detailed Instructions
puts "\n6. Image Analysis with Detailed Instructions"
puts '-' * 80

response = LlmConductor.generate(
  model: 'claude-sonnet-4-20250514',
  vendor: :anthropic,
  prompt: {
    text: 'Analyze this image and provide: 1) Main subjects, 2) Colors and lighting, 3) Mood or atmosphere, 4) Any notable details',
    images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/1024px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  }
)

puts "Response: #{response.output}"
puts "Tokens: #{response.input_tokens} input, #{response.output_tokens} output"

puts "\n#{'=' * 80}"
puts 'All examples completed successfully!'
puts '=' * 80
