# frozen_string_literal: true

module LlmConductor
  # Factory class for creating appropriate LLM client instances based on model and vendor
  class ClientFactory
    def self.build(model:, type:, vendor: nil)
      vendor ||= determine_vendor(model)

      client_class = case vendor
                     when :anthropic, :claude
                       Clients::AnthropicClient
                     when :openai, :gpt
                       Clients::GptClient
                     when :openrouter
                       Clients::OpenrouterClient
                     when :ollama
                       Clients::OllamaClient
                     when :gemini, :google
                       Clients::GeminiClient
                     else
                       raise ArgumentError,
                             "Unsupported vendor: #{vendor}. Supported vendors: anthropic, openai, openrouter, ollama, gemini"
                     end

      client_class.new(model:, type:)
    end

    def self.determine_vendor(model)
      case model
      when /^claude/i
        :anthropic
      when /^gpt/i
        :openai
      when /^gemini/i
        :gemini
      else
        :ollama # Default to Ollama for non-specific model names
      end
    end
  end
end
