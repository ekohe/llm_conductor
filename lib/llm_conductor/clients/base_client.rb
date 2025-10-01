# frozen_string_literal: true

require 'tiktoken_ruby'
require 'ollama-ai'
require 'openai'

module LlmConductor
  module Clients
    # Base client class providing common functionality for all LLM providers
    # including prompt building, token counting, and response formatting.
    class BaseClient
      include Prompts

      attr_reader :model, :type

      def initialize(model:, type:)
        @model = model
        @type = type
      end

      def generate(data:)
        prompt = build_prompt(data)
        input_tokens = calculate_tokens(prompt)
        output_text = generate_content(prompt)
        output_tokens = calculate_tokens(output_text || '')

        # Logging AI request metadata if logger is set
        configuration.logger&.debug(
          "Vendor: #{vendor_name}, Model: #{@model} " \
          "Output_tokens: #{output_tokens} Input_tokens: #{input_tokens}"
        )

        build_response(output_text, input_tokens, output_tokens, { prompt: })
      rescue StandardError => e
        build_error_response(e)
      end

      # Simple generation method that accepts a direct prompt and returns a Response object
      def generate_simple(prompt:)
        input_tokens = calculate_tokens(prompt)
        output_text = generate_content(prompt)
        output_tokens = calculate_tokens(output_text || '')

        # Logging AI request metadata if logger is set
        configuration.logger&.debug(
          "Vendor: #{vendor_name}, Model: #{@model} " \
          "Output_tokens: #{output_tokens} Input_tokens: #{input_tokens}"
        )

        build_response(output_text, input_tokens, output_tokens)
      rescue StandardError => e
        build_error_response(e)
      end

      private

      def build_response(output_text, input_tokens, output_tokens, additional_metadata = {})
        Response.new(
          output: output_text,
          model:,
          input_tokens:,
          output_tokens:,
          metadata: build_metadata.merge(additional_metadata)
        )
      end

      def build_error_response(error)
        Response.new(
          output: nil,
          model:,
          metadata: { error: error.message, error_class: error.class.name }
        )
      end

      def build_prompt(data)
        # Check if this is a registered prompt type
        if PromptManager.registered?(type)
          PromptManager.render(type, data)
        else
          # Fallback to legacy prompt methods
          send(:"prompt_#{type}", data)
        end
      end

      def generate_content(prompt)
        raise NotImplementedError
      end

      def calculate_tokens(content)
        encoder.encode(content).length
      end

      def encoder
        @encoder ||= Tiktoken.get_encoding('cl100k_base')
      end

      def client
        raise NotImplementedError
      end

      # Build metadata for the response
      def build_metadata
        {
          vendor: vendor_name,
          timestamp: Time.now.utc.iso8601
        }
      end

      def vendor_name
        self.class.name.split('::').last.gsub('Client', '').downcase.to_sym
      end

      def configuration
        LlmConductor.configuration
      end
    end
  end
end
