# frozen_string_literal: true

module LlmConductor
  # Factory class for creating appropriate LLM client instances based on model and vendor
  class ClientFactory
    def self.build(model:, type:, vendor: nil)
      vendor ||= determine_vendor(model)
      client_class = client_class_for_vendor(vendor)
      client_class.new(model:, type:)
    end

    def self.client_class_for_vendor(vendor)
      client_classes = {
        anthropic: Clients::AnthropicClient,
        claude: Clients::AnthropicClient,
        openai: Clients::GptClient,
        gpt: Clients::GptClient,
        openrouter: Clients::OpenrouterClient,
        ollama: Clients::OllamaClient,
        gemini: Clients::GeminiClient,
        google: Clients::GeminiClient,
        groq: Clients::GroqClient
      }

      client_classes[vendor] || raise(
        ArgumentError,
        "Unsupported vendor: #{vendor}. " \
        'Supported vendors: anthropic, openai, openrouter, ollama, gemini, groq'
      )
    end

    def self.determine_vendor(model)
      case model
      when /^claude/i
        :anthropic
      when /^gpt/i
        :openai
      when /^gemini/i
        :gemini
      when /^(llama|mixtral|gemma|qwen)/i
        :groq
      else
        :ollama # Default to Ollama for non-specific model names
      end
    end
  end
end
