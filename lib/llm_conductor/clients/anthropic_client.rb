# frozen_string_literal: true

require 'anthropic'

module LlmConductor
  module Clients
    # Anthropic Claude client implementation for accessing Claude models via Anthropic API
    # Supports both text-only and multimodal (vision) requests
    class AnthropicClient < BaseClient
      private

      # Override token calculation to handle multimodal content
      def calculate_tokens(content)
        case content
        when String
          super(content)
        when Hash
          # For multimodal content, count tokens only for text part
          # Note: This is an approximation as images have variable token counts
          text = content[:text] || content['text'] || ''
          super(text)
        when Array
          # For pre-formatted arrays, extract and count text parts
          text_parts = content.select { |part| part[:type] == 'text' || part['type'] == 'text' }
                              .map { |part| part[:text] || part['text'] || '' }
                              .join(' ')
          super(text_parts)
        else
          super(content.to_s)
        end
      end

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

      # Format content based on whether it's a simple string or multimodal content
      # @param prompt [String, Hash, Array] The prompt content
      # @return [String, Array] Formatted content for the API
      def format_content(prompt)
        case prompt
        when Hash
          # Handle hash with text and/or images
          format_multimodal_hash(prompt)
        when Array
          # Already formatted as array of content parts
          prompt
        else
          # Simple string prompt
          prompt.to_s
        end
      end

      # Format a hash containing text and/or images into multimodal content array
      # @param prompt_hash [Hash] Hash with :text and/or :images keys
      # @return [Array] Array of content parts for the API (Anthropic format)
      def format_multimodal_hash(prompt_hash)
        content_parts = []

        # Add image parts first (Anthropic recommends images before text)
        images = prompt_hash[:images] || prompt_hash['images'] || []
        images = [images] unless images.is_a?(Array)

        images.each do |image|
          content_parts << format_image_part(image)
        end

        # Add text part if present
        if prompt_hash[:text] || prompt_hash['text']
          text = prompt_hash[:text] || prompt_hash['text']
          content_parts << { type: 'text', text: }
        end

        content_parts
      end

      # Format an image into the appropriate API structure for Anthropic
      # @param image [String, Hash] Image URL or hash with url/detail keys
      # @return [Hash] Formatted image part for the API
      def format_image_part(image)
        case image
        when String
          # Simple URL string - Anthropic format
          { type: 'image', source: { type: 'url', url: image } }
        when Hash
          # Hash with url and optional detail level
          # Note: Anthropic doesn't have a 'detail' parameter like OpenAI
          {
            type: 'image',
            source: {
              type: 'url',
              url: image[:url] || image['url']
            }
          }
        end
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
