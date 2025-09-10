# frozen_string_literal: true

module LlmConductor
  class ClientFactory
    VENDOR_MODEL_MAPPING = {
      openai: %w[gpt-3.5-turbo gpt-4 gpt-4-turbo gpt-4o],
      ollama: %w[llama2 llama3 mistral codellama],
      openrouter: %w[meta-llama anthropic/claude openai/gpt],
      anthropic: %w[claude-3-haiku claude-3-sonnet claude-3-opus]
    }.freeze

    def self.build(model:, type: nil, vendor: nil, configuration: nil, **options)
      config = configuration || LlmConductor.configuration
      vendor = determine_vendor(model: model, vendor: vendor, configuration: config)
      
      client_class = client_class_for_vendor(vendor)
      client_class.new(
        model: model,
        type: type,
        configuration: config,
        **options
      )
    end

    private

    def self.determine_vendor(model:, vendor:, configuration:)
      return vendor.to_sym if vendor

      # Try to determine vendor from model name
      VENDOR_MODEL_MAPPING.each do |vendor_name, model_prefixes|
        model_prefixes.each do |prefix|
          return vendor_name if model.to_s.start_with?(prefix)
        end
      end

      # Fallback to default vendor
      configuration.default_vendor
    end

    def self.client_class_for_vendor(vendor)
      case vendor.to_sym
      when :openai
        Clients::OpenAIClient
      when :ollama
        Clients::OllamaClient
      when :openrouter
        Clients::OpenRouterClient
      when :anthropic
        Clients::AnthropicClient
      else
        raise ConfigurationError, "Unsupported vendor: #{vendor}"
      end
    end
  end
end
