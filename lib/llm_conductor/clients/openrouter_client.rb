# frozen_string_literal: true

require_relative 'concerns/vision_support'

module LlmConductor
  module Clients
    # OpenRouter client implementation for accessing various LLM providers through OpenRouter API
    # Supports both text-only and multimodal (vision) requests
    class OpenrouterClient < BaseClient
      include Concerns::VisionSupport

      private

      def generate_content(prompt)
        content = format_content(prompt)

        # Retry logic for transient 502 errors (common with free-tier models)
        # Free-tier vision models can be slow/overloaded, so we use more retries
        max_retries = 5
        retry_count = 0

        begin
          client.chat(
            parameters: {
              model:,
              messages: [{ role: 'user', content: }],
              provider: { sort: 'throughput' }
            }
          ).dig('choices', 0, 'message', 'content')
        rescue Faraday::ServerError => e
          retry_count += 1

          # Log retry attempts if logger is configured
          configuration.logger&.warn(
            "OpenRouter API error (attempt #{retry_count}/#{max_retries}): #{e.message}"
          )

          raise unless e.response[:status] == 502 && retry_count < max_retries

          wait_time = 2**retry_count # Exponential backoff: 2, 4, 8, 16, 32 seconds
          configuration.logger&.info("Retrying in #{wait_time}s...")
          sleep(wait_time)
          retry
        end
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
