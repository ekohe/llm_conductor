# frozen_string_literal: true

# LLM Conductor provides a unified interface for multiple Language Model providers
module LlmConductor
  # Configuration class for managing API keys, endpoints, and default settings
  class Configuration
    attr_accessor :default_model, :default_vendor, :timeout, :max_retries, :retry_delay, :logger
    attr_reader :providers

    def initialize
      # Default settings
      @default_model = 'gpt-5-mini'
      @default_vendor = :openai
      @timeout = 30
      @max_retries = 3
      @retry_delay = 1.0
      @logger = nil

      # Provider configurations
      @providers = {}

      # Initialize with environment variables if available
      setup_defaults_from_env
    end

    # Configure Anthropic provider
    def anthropic(api_key: nil, **options)
      @providers[:anthropic] = {
        api_key: api_key || ENV['ANTHROPIC_API_KEY'],
        **options
      }
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

    # Configure Google Gemini provider (Generative Language API or Vertex AI)
    #
    # For the standard Generative Language API, provide api_key.
    # For Vertex AI, provide project_id and optionally region (defaults to 'global').
    # Authentication falls back to Application Default Credentials
    # (ADC / GOOGLE_APPLICATION_CREDENTIALS) when neither file_path nor file_contents is supplied.
    # Env vars (GEMINI_API_KEY, GOOGLE_VERTEX_PROJECT_ID, etc.) are only applied automatically
    # on boot via setup_defaults_from_env — explicit calls use only what is passed.
    def gemini(api_key: nil, project_id: nil, region: nil, file_path: nil, file_contents: nil, **options)
      @providers[:gemini] = {
        api_key:,
        project_id:,
        region: region || 'global',
        file_path:,
        file_contents:,
        **options
      }.compact
    end

    # Configure Groq provider
    def groq(api_key: nil, **options)
      @providers[:groq] = {
        api_key: api_key || ENV['GROQ_API_KEY'],
        **options
      }
    end

    # Configure Z.ai provider
    def zai(api_key: nil, **options)
      @providers[:zai] = {
        api_key: api_key || ENV['ZAI_API_KEY'],
        **options
      }
    end

    # Get provider configuration
    def provider_config(provider)
      @providers[provider.to_sym] || {}
    end

    # Legacy compatibility methods
    def anthropic_api_key
      provider_config(:anthropic)[:api_key]
    end

    def anthropic_api_key=(value)
      anthropic(api_key: value)
    end

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

    def gemini_api_key
      provider_config(:gemini)[:api_key]
    end

    def gemini_api_key=(value)
      gemini(api_key: value)
    end

    def groq_api_key
      provider_config(:groq)[:api_key]
    end

    def groq_api_key=(value)
      groq(api_key: value)
    end

    def zai_api_key
      provider_config(:zai)[:api_key]
    end

    def zai_api_key=(value)
      zai(api_key: value)
    end

    private

    def setup_defaults_from_env
      # Auto-configure providers if environment variables are present
      anthropic if ENV['ANTHROPIC_API_KEY']
      openai if ENV['OPENAI_API_KEY']
      openrouter if ENV['OPENROUTER_API_KEY']
      setup_gemini_from_env
      groq if ENV['GROQ_API_KEY']
      zai if ENV['ZAI_API_KEY']
      ollama # Always configure Ollama with default URL
    end

    def setup_gemini_from_env
      return unless ENV.values_at(
        'GEMINI_API_KEY', 'GOOGLE_VERTEX_PROJECT_ID',
        'GOOGLE_APPLICATION_CREDENTIALS', 'GOOGLE_CREDENTIALS_FILE_CONTENTS'
      ).any?

      gemini(
        api_key: ENV['GEMINI_API_KEY'],
        project_id: ENV['GOOGLE_VERTEX_PROJECT_ID'],
        region: ENV['GOOGLE_VERTEX_REGION'],
        file_path: ENV['GOOGLE_APPLICATION_CREDENTIALS'],
        file_contents: ENV['GOOGLE_CREDENTIALS_FILE_CONTENTS']
      )
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
