# frozen_string_literal: true

require 'gemini-ai'

module LlmConductor
  module Clients
    # Google Gemini client implementation for accessing Gemini models via Google AI API
    class GeminiClient < BaseClient
      private

      def generate_content(prompt)
        client.generate_content(
          contents: [
            { parts: [{ text: prompt }] }
          ]
        ).dig('candidates', 0, 'content', 'parts', 0, 'text')
      end

      def client
        @client ||= begin
          config = LlmConductor.configuration.provider_config(:gemini)
          Gemini.new(
            credentials: {
              service: 'generative-language-api',
              api_key: config[:api_key]
            },
            options: { model: }
          )
        end
      end
    end
  end
end
