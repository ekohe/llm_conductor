# frozen_string_literal: true

module LlmConductor
  module Clients
    # Ollama client implementation for accessing local or self-hosted Ollama models
    class OllamaClient < BaseClient
      private

      def generate_content(prompt)
        client.generate({ model:, prompt:, stream: false }).first['response']
      end

      def client
        @client ||= begin
          config = LlmConductor.configuration.provider_config(:ollama)
          Ollama.new(
            credentials: { address: config[:base_url] },
            options: { server_sent_events: true }
          )
        end
      end
    end
  end
end
