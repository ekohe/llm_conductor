#!/usr/bin/env ruby
# frozen_string_literal: true

# Example of OpenRouter vision/multimodal usage
require_relative '../lib/llm_conductor'

# Configure OpenRouter
LlmConductor.configure do |config|
  config.openrouter(
    api_key: ENV['OPENROUTER_API_KEY']
  )
end

# Example 1: Simple text-only request (backward compatible)
puts '=== Example 1: Text-only request ==='
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free', # Free vision-capable model
  vendor: :openrouter,
  prompt: 'What is the capital of France?'
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"

# Example 2: Vision request with a single image
puts '=== Example 2: Single image analysis ==='
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: {
    text: 'What is in this image?',
    images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  }
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"

# Example 3: Vision request with multiple images
puts '=== Example 3: Multiple images comparison ==='
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: {
    text: 'Compare these two images and describe the differences.',
    images: [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Placeholder_view_vector.svg/681px-Placeholder_view_vector.svg.png'
    ]
  }
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"

# Example 4: Image with detail level specification
puts '=== Example 4: Image with detail level ==='
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: {
    text: 'Describe this image in detail.',
    images: [
      {
        url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg',
        detail: 'high'
      }
    ]
  }
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"

# Example 5: Using raw array format (advanced)
puts '=== Example 5: Raw array format ==='
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: [
    { type: 'text', text: 'What is in this image?' },
    {
      type: 'image_url',
      image_url: {
        url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
      }
    }
  ]
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"

# Example 6: Error handling
puts '=== Example 6: Error handling ==='
begin
  response = LlmConductor.generate(
    model: 'nvidia/nemotron-nano-12b-v2-vl:free',
    vendor: :openrouter,
    prompt: {
      text: 'Analyze this image',
      images: 'invalid-url'
    }
  )

  if response.success?
    puts response.output
  else
    puts "Error: #{response.metadata[:error]}"
  end
rescue StandardError => e
  puts "Exception: #{e.message}"
end
