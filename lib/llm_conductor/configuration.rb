# frozen_string_literal: true

# LLM Conductor provides a unified interface for multiple Language Model providers
module LlmConductor
  # Configuration class for managing API keys, endpoints, and default settings
  class Configuration
    attr_accessor :default_model, :default_vendor, :timeout, :max_retries, :retry_delay
    attr_reader :providers

    def initialize
      # Default settings
      @default_model = 'gpt-5-mini'
      @default_vendor = :openai
      @timeout = 30
      @max_retries = 3
      @retry_delay = 1.0

      # Provider configurations
      @providers = {}

      # Initialize with environment variables if available
      setup_defaults_from_env
    end

    # Configure OpenAI provider
    def openai(api_key: nil, organization: nil, **options)
      @providers[:openai] = {
        api_key: api_key || ENV['OPENAI_API_KEY'],
        organization: organization || ENV['OPENAI_ORG_ID'],
        **options
      }
    end

    # Configure Ollama provider
    def ollama(base_url: nil, **options)
      @providers[:ollama] = {
        base_url: base_url || ENV['OLLAMA_ADDRESS'] || 'http://localhost:11434',
        **options
      }
    end

    # Configure OpenRouter provider
    def openrouter(api_key: nil, **options)
      @providers[:openrouter] = {
        api_key: api_key || ENV['OPENROUTER_API_KEY'],
        **options
      }
    end

    # Get provider configuration
    def provider_config(provider)
      @providers[provider.to_sym] || {}
    end

    # Legacy compatibility methods
    def openai_api_key
      provider_config(:openai)[:api_key]
    end

    def openai_api_key=(value)
      openai(api_key: value)
    end

    def openrouter_api_key
      provider_config(:openrouter)[:api_key]
    end

    def openrouter_api_key=(value)
      openrouter(api_key: value)
    end

    def ollama_address
      provider_config(:ollama)[:base_url]
    end

    def ollama_address=(value)
      ollama(base_url: value)
    end

    private

    def setup_defaults_from_env
      # Auto-configure providers if environment variables are present
      openai if ENV['OPENAI_API_KEY']
      openrouter if ENV['OPENROUTER_API_KEY']
      ollama # Always configure Ollama with default URL
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
