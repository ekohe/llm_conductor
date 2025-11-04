# frozen_string_literal: true

require 'anthropic'
require_relative 'concerns/vision_support'

module LlmConductor
  module Clients
    # Anthropic Claude client implementation for accessing Claude models via Anthropic API
    # Supports both text-only and multimodal (vision) requests
    class AnthropicClient < BaseClient
      include Concerns::VisionSupport

      private

      def generate_content(prompt)
        content = format_content(prompt)
        response = client.messages.create(
          model:,
          max_tokens: 4096,
          messages: [{ role: 'user', content: }]
        )

        response.content.first.text
      rescue Anthropic::Errors::APIError => e
        raise StandardError, "Anthropic API error: #{e.message}"
      end

      # Anthropic uses a different image format than OpenAI
      # Format: { type: 'image', source: { type: 'url', url: '...' } }
      def format_image_url(url)
        { type: 'image', source: { type: 'url', url: } }
      end

      def format_image_hash(image_hash)
        # Anthropic doesn't have a 'detail' parameter like OpenAI
        {
          type: 'image',
          source: {
            type: 'url',
            url: image_hash[:url] || image_hash['url']
          }
        }
      end

      # Anthropic recommends placing images before text
      def images_before_text?
        true
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
