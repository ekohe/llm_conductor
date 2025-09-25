# frozen_string_literal: true

require_relative '../lib/llm_conductor'

# Configure Gemini API key
LlmConductor.configure do |config|
  config.gemini_api_key = ENV['GEMINI_API_KEY'] || 'your_gemini_api_key_here'
end

# Example usage
response = LlmConductor.generate(
  model: 'gemini-2.5-flash',
  prompt: 'Explain how AI works in a few words'
)

puts "Model: #{response.model}"
puts "Output: #{response.output}"
puts "Vendor: #{response.metadata[:vendor]}"
