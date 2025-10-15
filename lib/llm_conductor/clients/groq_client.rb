# frozen_string_literal: true

module LlmConductor
  module Clients
    # Groq client implementation for accessing Groq models via Groq API
    class GroqClient < BaseClient
      private

      def generate_content(prompt)
        client.chat(
          messages: [{ role: 'user', content: prompt }],
          model:
        ).dig('choices', 0, 'message', 'content')
      end

      def client
        @client ||= begin
          config = LlmConductor.configuration.provider_config(:groq)
          Groq::Client.new(api_key: config[:api_key])
        end
      end
    end
  end
end
