# frozen_string_literal: true

require_relative 'concerns/vision_support'

module LlmConductor
  module Clients
    # Z.ai client implementation for accessing GLM models including GLM-4.5V
    # Supports both text-only and multimodal (vision) requests
    #
    # Note: Z.ai uses OpenAI-compatible API format but with /v4/ path instead of /v1/
    # We use Faraday directly instead of the ruby-openai gem to properly handle the API path
    class ZaiClient < BaseClient
      include Concerns::VisionSupport

      private

      def generate_content(prompt)
        content = format_content(prompt)

        # Retry logic for transient errors (similar to OpenRouter)
        max_retries = 3
        retry_count = 0

        begin
          # Make direct HTTP request to Z.ai API since they use /v4/ instead of /v1/
          response = http_client.post('chat/completions') do |req|
            req.body = {
              model:,
              messages: [{ role: 'user', content: }]
            }.to_json
          end

          # Response body is already parsed as Hash by Faraday's JSON middleware
          response_data = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
          response_data.dig('choices', 0, 'message', 'content')
        rescue Faraday::ServerError => e
          retry_count += 1

          # Log retry attempts if logger is configured
          configuration.logger&.warn(
            "Z.ai API error (attempt #{retry_count}/#{max_retries}): #{e.message}"
          )

          raise unless retry_count < max_retries

          wait_time = 2**retry_count # Exponential backoff: 2, 4, 8 seconds
          configuration.logger&.info("Retrying in #{wait_time}s...")
          sleep(wait_time)
          retry
        end
      end

      # HTTP client for making requests to Z.ai API
      # Z.ai uses /v4/ in their path, not /v1/ like OpenAI, so we use Faraday directly
      def http_client
        @http_client ||= begin
          config = LlmConductor.configuration.provider_config(:zai)
          base_url = config[:uri_base] || 'https://api.z.ai/api/paas/v4'

          Faraday.new(url: base_url) do |f|
            f.request :json
            f.response :json
            f.headers['Authorization'] = "Bearer #{config[:api_key]}"
            f.headers['Content-Type'] = 'application/json'
            f.adapter Faraday.default_adapter
          end
        end
      end

      # Legacy client method for compatibility (not used, but kept for reference)
      def client
        http_client
      end
    end
  end
end
