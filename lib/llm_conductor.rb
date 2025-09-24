# frozen_string_literal: true

require_relative 'llm_conductor/version'
require_relative 'llm_conductor/configuration'
require_relative 'llm_conductor/response'
require_relative 'llm_conductor/data_builder'
require_relative 'llm_conductor/prompts'
require_relative 'llm_conductor/prompts/base_prompt'
require_relative 'llm_conductor/prompt_manager'
require_relative 'llm_conductor/clients/base_client'
require_relative 'llm_conductor/clients/anthropic_client'
require_relative 'llm_conductor/clients/gpt_client'
require_relative 'llm_conductor/clients/ollama_client'
require_relative 'llm_conductor/clients/openrouter_client'
require_relative 'llm_conductor/clients/gemini_client'
require_relative 'llm_conductor/client_factory'

# LLM Conductor provides a unified interface for multiple Language Model providers
# including OpenAI GPT, OpenRouter, and Ollama with built-in prompt templates,
# token counting, and extensible client architecture.
module LlmConductor
  class Error < StandardError; end

  # Main entry point for creating LLM clients
  def self.build_client(model:, type:, vendor: nil)
    ClientFactory.build(model:, type:, vendor:)
  end

  # Unified generate method supporting both simple prompts and legacy template-based generation
  def self.generate(model: nil, prompt: nil, type: nil, data: nil, vendor: nil)
    if prompt && !type && !data
      generate_simple_prompt(model:, prompt:, vendor:)
    elsif type && data && !prompt
      generate_with_template(model:, type:, data:, vendor:)
    else
      raise ArgumentError,
            "Invalid arguments. Use either: generate(prompt: 'text') or generate(type: :custom, data: {...})"
    end
  end

  class << self
    private

    def generate_simple_prompt(model:, prompt:, vendor:)
      model ||= configuration.default_model
      vendor ||= ClientFactory.determine_vendor(model)
      client_class = client_class_for_vendor(vendor)
      client = client_class.new(model:, type: :direct)
      client.generate_simple(prompt:)
    end

    def generate_with_template(model:, type:, data:, vendor:)
      client = build_client(model:, type:, vendor:)
      client.generate(data:)
    end

    def client_class_for_vendor(vendor)
      case vendor
      when :anthropic, :claude then Clients::AnthropicClient
      when :openai, :gpt then Clients::GptClient
      when :openrouter then Clients::OpenrouterClient
      when :ollama then Clients::OllamaClient
      else
        raise ArgumentError, "Unsupported vendor: #{vendor}. Supported vendors: anthropic, openai, openrouter, ollama"
      end
    end
  end

  # List of supported vendors
  SUPPORTED_VENDORS = %i[anthropic openai openrouter ollama].freeze

  # List of supported prompt types
  SUPPORTED_PROMPT_TYPES = %i[
    featured_links
    summarize_htmls
    summarize_description
    custom
  ].freeze
end
