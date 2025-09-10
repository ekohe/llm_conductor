# frozen_string_literal: true

require 'ollama-ai'

module LlmConductor
  module Clients
    class OllamaClient < BaseClient
      private

      def generate_content(prompt)
        response = client.generate(
          model: model,
          prompt: prompt.to_s,
          stream: false,
          options: {
            temperature: options[:temperature],
            top_p: options[:top_p],
            top_k: options[:top_k],
            num_predict: options[:max_tokens]
          }.compact
        )

        # Ollama returns an array of responses
        response.first['response'] if response.is_a?(Array) && response.any?
      end

      def stream_content(prompt, &block)
        client.generate(
          model: model,
          prompt: prompt.to_s,
          stream: true
        ) do |chunk|
          block.call(chunk) if chunk && chunk['response']
        end
      end

      def build_client
        config = provider_config
        
        Ollama.new(
          credentials: { address: config[:base_url] },
          options: { 
            server_sent_events: true,
            timeout: configuration.timeout
          }
        )
      end
    end
  end
end
