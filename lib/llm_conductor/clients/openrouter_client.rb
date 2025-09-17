# frozen_string_literal: true

module LlmConductor
  module Clients
    # OpenRouter client implementation for accessing various LLM providers through OpenRouter API
    class OpenrouterClient < BaseClient
      private

      def generate_content(prompt)
        client.chat(
          parameters: {
            model:,
            messages: [{ role: 'user', content: prompt }],
            provider: { sort: 'throughput' }
          }
        ).dig('choices', 0, 'message', 'content')
      end

      def client
        @client ||= begin
          config = LlmConductor.configuration.provider_config(:openrouter)
          OpenAI::Client.new(
            access_token: config[:api_key],
            uri_base: config[:uri_base] || 'https://openrouter.ai/api/'
          )
        end
      end
    end
  end
end
