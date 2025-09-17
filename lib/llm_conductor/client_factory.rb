# frozen_string_literal: true

module LlmConductor
  # Factory class for creating appropriate LLM client instances based on model and vendor
  class ClientFactory
    def self.build(model:, type:, vendor: nil)
      vendor ||= determine_vendor(model)

      client_class = case vendor
                     when :openai, :gpt
                       Clients::GptClient
                     when :openrouter
                       Clients::OpenrouterClient
                     when :ollama
                       Clients::OllamaClient
                     else
                       raise ArgumentError,
                             "Unsupported vendor: #{vendor}. Supported vendors: openai, openrouter, ollama"
                     end

      client_class.new(model:, type:)
    end

    def self.determine_vendor(model)
      case model
      when /^gpt/i
        :openai
      else
        :ollama # Default to Ollama for non-specific model names
      end
    end
  end
end
