# frozen_string_literal: true

module LlmConductor
  module Clients
    # Groq client implementation for accessing Groq models via Groq API
    class GroqClient < BaseClient
      private

      def generate_content(prompt)
        # Groq::Client.chat expects messages as positional arg, not keyword arg
        messages = [{ role: 'user', content: prompt }]
        client.chat(messages, model_id: model)['content']
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
