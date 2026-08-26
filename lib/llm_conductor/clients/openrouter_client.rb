# frozen_string_literal: true

require_relative 'concerns/vision_support'

module LlmConductor
  module Clients
    # OpenRouter client implementation for accessing various LLM providers through OpenRouter API
    # Supports both text-only and multimodal (vision) requests
    #
    # Transient failures (502s from overloaded free-tier models, rate limits,
    # timeouts) are retried by BaseClient's Concerns::Retryable using
    # configuration.max_retries / configuration.retry_delay.
    class OpenrouterClient < BaseClient
      include Concerns::VisionSupport

      private

      def generate_content(prompt)
        content = format_content(prompt)

        client.chat(
          parameters: {
            model:,
            messages: [{ role: 'user', content: }],
            provider: { sort: 'throughput' }
          }
        ).dig('choices', 0, 'message', 'content')
      end

      def client
        @client ||= begin
          config = LlmConductor.configuration.provider_config(:openrouter)
          OpenAI::Client.new(
            access_token: config[:api_key],
            uri_base: config[:uri_base] || 'https://openrouter.ai/api/v1'
          )
        end
      end
    end
  end
end
