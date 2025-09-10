# frozen_string_literal: true

require 'openai'

module LlmConductor
  module Clients
    class OpenAIClient < BaseClient
      private

      def generate_content(prompt)
        messages = format_messages(prompt)
        
        response = client.chat(
          parameters: {
            model: model,
            messages: messages,
            temperature: options[:temperature] || 0.7,
            max_tokens: options[:max_tokens],
            top_p: options[:top_p],
            frequency_penalty: options[:frequency_penalty],
            presence_penalty: options[:presence_penalty]
          }.compact
        )

        extract_content_from_response(response)
      end

      def stream_content(prompt, &block)
        messages = format_messages(prompt)
        
        client.chat(
          parameters: {
            model: model,
            messages: messages,
            stream: proc { |chunk| block.call(chunk) },
            temperature: options[:temperature] || 0.7,
            max_tokens: options[:max_tokens]
          }.compact
        )
      end

      def build_client
        config = provider_config
        
        OpenAI::Client.new(
          access_token: config[:api_key],
          uri_base: config[:base_url],
          organization: config[:organization],
          request_timeout: configuration.timeout
        )
      end

      def extract_content_from_response(response)
        response.dig('choices', 0, 'message', 'content')
      end
    end
  end
end
