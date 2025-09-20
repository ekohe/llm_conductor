# frozen_string_literal: true

require 'anthropic'

module LlmConductor
  module Clients
    # Anthropic Claude client implementation for accessing Claude models via Anthropic API
    class AnthropicClient < BaseClient
      private

      def generate_content(prompt)
        response = client.messages.create(
          model:,
          max_tokens: 4096,
          messages: [{ role: 'user', content: prompt }]
        )

        response.content.first.text
      rescue Anthropic::Errors::APIError => e
        raise StandardError, "Anthropic API error: #{e.message}"
      end

      def client
        @client ||= begin
          config = LlmConductor.configuration.provider_config(:anthropic)
          Anthropic::Client.new(api_key: config[:api_key])
        end
      end
    end
  end
end
