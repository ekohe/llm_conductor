#!/usr/bin/env ruby
# frozen_string_literal: true

# Example of Z.ai GLM model usage including multimodal/vision capabilities
require_relative '../lib/llm_conductor'

# Configure Z.ai
LlmConductor.configure do |config|
  config.zai(
    api_key: ENV['ZAI_API_KEY']
  )
end

# Example 1: Simple text-only request with GLM-4-plus
puts '=== Example 1: Text-only request with GLM-4-plus ==='
response = LlmConductor.generate(
  model: 'glm-4-plus',
  vendor: :zai,
  prompt: 'What is the capital of France? Please answer in one sentence.'
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"

# Example 2: Text request with GLM-4.5V (vision model, text-only mode)
puts '=== Example 2: Text-only request with GLM-4.5V ==='
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: 'Explain the concept of machine learning in simple terms.'
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"

# Example 3: Vision request with a single image
puts '=== Example 3: Single image analysis with GLM-4.5V ==='
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: {
    text: 'What do you see in this image? Please describe it in detail.',
    images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  }
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"

# Example 4: Vision request with multiple images
puts '=== Example 4: Multiple images comparison with GLM-4.5V ==='
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: {
    text: 'Compare these two images and describe the differences you observe.',
    images: [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Placeholder_view_vector.svg/681px-Placeholder_view_vector.svg.png'
    ]
  }
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"

# Example 5: Image with detail level specification
puts '=== Example 5: Image with detail level ==='
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: {
    text: 'Describe this image in detail, including colors, objects, and atmosphere.',
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

# Example 6: Using raw array format (advanced)
puts '=== Example 6: Raw array format ==='
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: [
    { type: 'text', text: 'What objects can you identify in this image?' },
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

# Example 7: Base64 encoded image (for local images)
puts '=== Example 7: Using base64 encoded image ==='
# NOTE: In real usage, you would read and encode a local file
# require 'base64'
# image_data = Base64.strict_encode64(File.read('path/to/image.jpg'))
# image_url = "data:image/jpeg;base64,#{image_data}"

# For this example, we'll use a URL
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: {
    text: 'Analyze this image and extract any text you can see.',
    images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  }
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"

# Example 8: Error handling
puts '=== Example 8: Error handling ==='
begin
  response = LlmConductor.generate(
    model: 'glm-4.5v',
    vendor: :zai,
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

# Example 9: Document understanding (OCR)
puts "\n=== Example 9: Document understanding ==="
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: {
    text: 'Please read any text visible in this image and transcribe it.',
    images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  }
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"

# Example 10: Complex reasoning with image
puts '=== Example 10: Complex reasoning with image ==='
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: {
    text: 'Based on this image, what time of day do you think it is? Explain your reasoning.',
    images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  }
)
puts response.output
puts "Tokens used: #{response.total_tokens}\n\n"
