# frozen_string_literal: true

# Example configuration file for LlmConductor
# Place this file in config/initializers/llm_conductor.rb in Rails applications

LlmConductor.configure do |config|
  # Default settings
  config.default_model = 'gpt-5-mini'
  config.default_vendor = :openai
  config.timeout = 30
  # Retries on transient failures (429/5xx, connection & read timeouts).
  # max_retries is the TOTAL attempt budget including the first call, so 3 means
  # one call plus at most two retries. retry_delay seeds an exponential backoff
  # (~1s, ~2s, ~4s ...) with jitter. See docs/retries.md.
  config.max_retries = 3
  config.retry_delay = 1.0
  # Use Ruby's built-in Logger class directly
  config.logger = Logger.new($stdout)
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
