# frozen_string_literal: true

# Example configuration file for LlmConductor
# Place this file in config/initializers/llm_conductor.rb in Rails applications

LlmConductor.configure do |config|
  # Default settings
  config.default_model = 'gpt-5-mini'
  config.default_vendor = :openai
  config.timeout = 30
  config.max_retries = 3
  config.retry_delay = 1.0
  config.log_level = :warn # Options: :debug, :info, :warn, :error, :fatal

  # Configure providers
  config.openai(
    api_key: ENV['OPENAI_API_KEY'],
    organization: ENV['OPENAI_ORG_ID'] # optional
  )

  config.ollama(
    base_url: ENV['OLLAMA_ADDRESS'] || 'http://localhost:11434'
  )

  config.openrouter(
    api_key: ENV['OPENROUTER_API_KEY']
  )
end
