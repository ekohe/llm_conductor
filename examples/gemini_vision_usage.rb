# frozen_string_literal: true

require_relative '../lib/llm_conductor'

# Configure Gemini API key
LlmConductor.configure do |config|
  config.gemini(api_key: ENV['GEMINI_API_KEY'] || 'your_gemini_api_key_here')
end

puts '=' * 80
puts 'Google Gemini Vision Examples'
puts '=' * 80
puts

# Example 1: Single image analysis (simple format)
puts 'Example 1: Single Image Analysis'
puts '-' * 40

response = LlmConductor.generate(
  model: 'gemini-2.0-flash',
  vendor: :gemini,
  prompt: {
    text: 'What is in this image? Describe it in detail.',
    images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  }
)

puts "Model: #{response.model}"
puts "Vendor: #{response.metadata[:vendor]}"
puts "Input tokens: #{response.input_tokens}"
puts "Output tokens: #{response.output_tokens}"
puts "\nResponse:"
puts response.output
puts

# Example 2: Multiple images comparison
puts '=' * 80
puts 'Example 2: Multiple Images Comparison'
puts '-' * 40

response = LlmConductor.generate(
  model: 'gemini-2.0-flash',
  vendor: :gemini,
  prompt: {
    text: 'Compare these images. What are the main differences?',
    images: [
      'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Placeholder_view_vector.svg/681px-Placeholder_view_vector.svg.png'
    ]
  }
)

puts "Model: #{response.model}"
puts "Input tokens: #{response.input_tokens}"
puts "Output tokens: #{response.output_tokens}"
puts "\nResponse:"
puts response.output
puts

# Example 3: Raw format with Gemini-specific structure
puts '=' * 80
puts 'Example 3: Raw Format (Gemini-specific)'
puts '-' * 40

response = LlmConductor.generate(
  model: 'gemini-2.0-flash',
  vendor: :gemini,
  prompt: [
    { type: 'text', text: 'Analyze this nature scene:' },
    { type: 'image_url', image_url: { url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg' } },
    { type: 'text', text: 'What time of day do you think this photo was taken?' }
  ]
)

puts "Model: #{response.model}"
puts "Input tokens: #{response.input_tokens}"
puts "Output tokens: #{response.output_tokens}"
puts "\nResponse:"
puts response.output
puts

# Example 4: Image with specific analysis request
puts '=' * 80
puts 'Example 4: Specific Analysis Request'
puts '-' * 40

response = LlmConductor.generate(
  model: 'gemini-2.0-flash',
  vendor: :gemini,
  prompt: {
    text: 'Count the number of distinct colors visible in this image and list them.',
    images: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  }
)

puts "Model: #{response.model}"
puts "\nResponse:"
puts response.output
puts

# Example 5: Error handling
puts '=' * 80
puts 'Example 5: Error Handling'
puts '-' * 40

begin
  response = LlmConductor.generate(
    model: 'gemini-2.0-flash',
    vendor: :gemini,
    prompt: {
      text: 'What is in this image?',
      images: 'https://example.com/nonexistent-image.jpg'
    }
  )

  if response.success?
    puts 'Success! Response:'
    puts response.output
  else
    puts "Request failed: #{response.metadata[:error]}"
  end
rescue StandardError => e
  puts "Error occurred: #{e.message}"
end
puts

# Example 6: Text-only request (backward compatibility)
puts '=' * 80
puts 'Example 6: Text-Only Request (No Images)'
puts '-' * 40

response = LlmConductor.generate(
  model: 'gemini-2.0-flash',
  vendor: :gemini,
  prompt: 'Explain how neural networks work in 3 sentences.'
)

puts "Model: #{response.model}"
puts "Input tokens: #{response.input_tokens}"
puts "Output tokens: #{response.output_tokens}"
puts "\nResponse:"
puts response.output
puts

# Example 7: Image with hash format (URL specified explicitly)
puts '=' * 80
puts 'Example 7: Image Hash Format'
puts '-' * 40

response = LlmConductor.generate(
  model: 'gemini-2.0-flash',
  vendor: :gemini,
  prompt: {
    text: 'Describe the mood and atmosphere of this image.',
    images: [
      { url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg' }
    ]
  }
)

puts "Model: #{response.model}"
puts "\nResponse:"
puts response.output
puts

puts '=' * 80
puts 'Examples completed!'
puts '=' * 80
