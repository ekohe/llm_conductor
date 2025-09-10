# frozen_string_literal: true

module LlmConductor
  class Configuration
    attr_accessor :default_model, :default_vendor, :timeout, :max_retries, :retry_delay
    attr_reader :providers

    def initialize
      @providers = {}
      @default_model = 'gpt-3.5-turbo'
      @default_vendor = :openai
      @timeout = 30
      @max_retries = 3
      @retry_delay = 1.0
    end

    def add_provider(name, config = {})
      @providers[name.to_sym] = config
    end

    def openai(api_key: nil, base_url: nil, organization: nil, **options)
      add_provider(:openai, {
        api_key: api_key || ENV['OPENAI_API_KEY'],
        base_url: base_url || 'https://api.openai.com/v1',
        organization: organization,
        **options
      })
    end

    def ollama(base_url: nil, **options)
      add_provider(:ollama, {
        base_url: base_url || ENV.fetch('OLLAMA_ADDRESS', 'http://localhost:11434'),
        **options
      })
    end

    def openrouter(api_key: nil, base_url: nil, **options)
      add_provider(:openrouter, {
        api_key: api_key || ENV['OPENROUTER_API_KEY'],
        base_url: base_url || 'https://openrouter.ai/api/v1',
        **options
      })
    end

    def anthropic(api_key: nil, base_url: nil, **options)
      add_provider(:anthropic, {
        api_key: api_key || ENV['ANTHROPIC_API_KEY'],
        base_url: base_url || 'https://api.anthropic.com/v1',
        **options
      })
    end

    def provider_config(name)
      config = @providers[name.to_sym]
      raise ConfigurationError, "Provider #{name} not configured" unless config
      
      config
    end

    def configured_providers
      @providers.keys
    end
  end
end
