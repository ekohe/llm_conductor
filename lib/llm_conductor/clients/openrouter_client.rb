# frozen_string_literal: true

module LlmConductor
  module Clients
    # OpenRouter client implementation for accessing various LLM providers through OpenRouter API
    # Supports both text-only and multimodal (vision) requests
    class OpenrouterClient < BaseClient
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

        # Retry logic for transient 502 errors (common with free-tier models)
        # Free-tier vision models can be slow/overloaded, so we use more retries
        max_retries = 5
        retry_count = 0

        begin
          client.chat(
            parameters: {
              model:,
              messages: [{ role: 'user', content: }],
              provider: { sort: 'throughput' }
            }
          ).dig('choices', 0, 'message', 'content')
        rescue Faraday::ServerError => e
          retry_count += 1

          # Log retry attempts if logger is configured
          configuration.logger&.warn(
            "OpenRouter API error (attempt #{retry_count}/#{max_retries}): #{e.message}"
          )

          raise unless e.response[:status] == 502 && retry_count < max_retries

          wait_time = 2**retry_count # Exponential backoff: 2, 4, 8, 16, 32 seconds
          configuration.logger&.info("Retrying in #{wait_time}s...")
          sleep(wait_time)
          retry
        end
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
      # @return [Array] Array of content parts for the API
      def format_multimodal_hash(prompt_hash)
        content_parts = []

        # Add text part if present
        if prompt_hash[:text] || prompt_hash['text']
          text = prompt_hash[:text] || prompt_hash['text']
          content_parts << { type: 'text', text: }
        end

        # Add image parts if present
        images = prompt_hash[:images] || prompt_hash['images'] || []
        images = [images] unless images.is_a?(Array)

        images.each do |image|
          content_parts << format_image_part(image)
        end

        content_parts
      end

      # Format an image into the appropriate API structure
      # @param image [String, Hash] Image URL or hash with url/detail keys
      # @return [Hash] Formatted image part for the API
      def format_image_part(image)
        case image
        when String
          # Simple URL string
          { type: 'image_url', image_url: { url: image } }
        when Hash
          # Hash with url and optional detail level
          {
            type: 'image_url',
            image_url: {
              url: image[:url] || image['url'],
              detail: image[:detail] || image['detail']
            }.compact
          }
        end
      end

      def client
        @client ||= begin
          config = LlmConductor.configuration.provider_config(:openrouter)
          OpenAI::Client.new(
            access_token: config[:api_key],
            uri_base: config[:uri_base] || 'https://openrouter.ai/api/v1'
          )
        end
      end
    end
  end
end
