# frozen_string_literal: true

require_relative 'logger'

module LlmConductor
  # Factory class for creating appropriate LLM client instances based on model and vendor
  class ClientFactory
    def self.build(model:, type:, vendor: nil)
      vendor ||= determine_vendor(model)
      client_class = client_class_for_vendor(vendor)

      Logger.info "Vendor: #{vendor}, Model: #{model}, Type: #{type}"

      client_class.new(model:, type:)
    end

    def self.client_class_for_vendor(vendor)
      case vendor
      when :anthropic, :claude
        Clients::AnthropicClient
      when :openai, :gpt
        Clients::GptClient
      when :openrouter
        Clients::OpenrouterClient
      when :ollama
        Clients::OllamaClient
      else
        raise ArgumentError,
              "Unsupported vendor: #{vendor}. Supported vendors: anthropic, openai, openrouter, ollama"
      end
    end

    def self.determine_vendor(model)
      case model
      when /^claude/i
        :anthropic
      when /^gpt/i
        :openai
      else
        :ollama # Default to Ollama for non-specific model names
      end
    end
  end
end
