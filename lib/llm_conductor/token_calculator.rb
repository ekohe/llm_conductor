# frozen_string_literal: true

module LlmConductor
  class TokenCalculator
    # Default encoding for OpenAI models
    DEFAULT_ENCODING = 'cl100k_base'

    def initialize(encoding: DEFAULT_ENCODING)
      @encoding = encoding
      @encoder = nil
    end

    def calculate(content)
      return 0 unless content
      
      content = content.to_s
      return 0 if content.empty?

      if tiktoken_available?
        encoder.encode(content).length
      else
        # Fallback estimation: roughly 4 characters per token
        (content.length / 4.0).ceil
      end
    end

    def estimate_cost(input_tokens:, output_tokens:, model:)
      pricing = PRICING[model.to_s]
      return nil unless pricing

      input_cost = (input_tokens / 1000.0) * pricing[:input]
      output_cost = (output_tokens / 1000.0) * pricing[:output]
      
      {
        input_cost: input_cost,
        output_cost: output_cost,
        total_cost: input_cost + output_cost,
        currency: 'USD'
      }
    end

    private

    def tiktoken_available?
      @tiktoken_checked ||= begin
        require 'tiktoken_ruby'
        true
      rescue LoadError
        false
      end
    end

    def encoder
      @encoder ||= begin
        require 'tiktoken_ruby'
        Tiktoken.get_encoding(@encoding)
      rescue LoadError
        nil
      end
    end

    # Approximate pricing per 1K tokens (USD)
    PRICING = {
      'gpt-3.5-turbo' => { input: 0.0015, output: 0.002 },
      'gpt-3.5-turbo-16k' => { input: 0.003, output: 0.004 },
      'gpt-4' => { input: 0.03, output: 0.06 },
      'gpt-4-32k' => { input: 0.06, output: 0.12 },
      'gpt-4-turbo' => { input: 0.01, output: 0.03 },
      'gpt-4o' => { input: 0.005, output: 0.015 },
      'claude-3-haiku' => { input: 0.00025, output: 0.00125 },
      'claude-3-sonnet' => { input: 0.003, output: 0.015 },
      'claude-3-opus' => { input: 0.015, output: 0.075 }
    }.freeze
  end
end
