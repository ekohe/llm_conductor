# frozen_string_literal: true

module LlmConductor
  module Clients
    # Z.ai client implementation for accessing GLM models including GLM-4.5V
    # Supports both text-only and multimodal (vision) requests
    #
    # Note: Z.ai uses OpenAI-compatible API format but with /v4/ path instead of /v1/
    # We use Faraday directly instead of the ruby-openai gem to properly handle the API path
    class ZaiClient < BaseClient
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

        # Retry logic for transient errors (similar to OpenRouter)
        max_retries = 3
        retry_count = 0

        begin
          # Make direct HTTP request to Z.ai API since they use /v4/ instead of /v1/
          response = http_client.post('chat/completions') do |req|
            req.body = {
              model:,
              messages: [{ role: 'user', content: }]
            }.to_json
          end

          # Response body is already parsed as Hash by Faraday's JSON middleware
          response_data = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
          response_data.dig('choices', 0, 'message', 'content')
        rescue Faraday::ServerError => e
          retry_count += 1

          # Log retry attempts if logger is configured
          configuration.logger&.warn(
            "Z.ai API error (attempt #{retry_count}/#{max_retries}): #{e.message}"
          )

          raise unless retry_count < max_retries

          wait_time = 2**retry_count # Exponential backoff: 2, 4, 8 seconds
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
          # Simple URL string or base64 data
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

      # HTTP client for making requests to Z.ai API
      # Z.ai uses /v4/ in their path, not /v1/ like OpenAI, so we use Faraday directly
      def http_client
        @http_client ||= begin
          config = LlmConductor.configuration.provider_config(:zai)
          base_url = config[:uri_base] || 'https://api.z.ai/api/paas/v4'

          Faraday.new(url: base_url) do |f|
            f.request :json
            f.response :json
            f.headers['Authorization'] = "Bearer #{config[:api_key]}"
            f.headers['Content-Type'] = 'application/json'
            f.adapter Faraday.default_adapter
          end
        end
      end

      # Legacy client method for compatibility (not used, but kept for reference)
      def client
        http_client
      end
    end
  end
end
