# frozen_string_literal: true

module LlmConductor
  module Clients
    module Concerns
      # Shared module for vision/multimodal support across different LLM clients
      # Provides common functionality for formatting images and text content
      module VisionSupport
        private

        # Override token calculation to handle multimodal content
        def calculate_tokens(content)
          case content
          when String then super(content)
          when Hash then calculate_tokens_from_hash(content)
          when Array then calculate_tokens_from_array(content)
          else super(content.to_s)
          end
        end

        # Calculate tokens from a hash containing text and/or images
        # @param content_hash [Hash] Hash with :text and/or :images keys
        # @return [Integer] Token count for text portion
        def calculate_tokens_from_hash(content_hash)
          text = content_hash[:text] || content_hash['text'] || ''
          # Call the parent class's calculate_tokens with the extracted text
          method(:calculate_tokens).super_method.call(text)
        end

        # Calculate tokens from an array of content parts
        # @param content_array [Array] Array of content parts with type and text
        # @return [Integer] Token count for all text parts
        def calculate_tokens_from_array(content_array)
          text_parts = extract_text_from_array(content_array)
          # Call the parent class's calculate_tokens with the joined text
          method(:calculate_tokens).super_method.call(text_parts)
        end

        # Extract and join text from array of content parts
        # @param content_array [Array] Array of content parts
        # @return [String] Joined text from all text parts
        def extract_text_from_array(content_array)
          content_array
            .select { |part| text_part?(part) }
            .map { |part| extract_text_from_part(part) }
            .join(' ')
        end

        # Check if a content part is a text part
        # @param part [Hash] Content part
        # @return [Boolean] true if part is a text type
        def text_part?(part)
          part[:type] == 'text' || part['type'] == 'text'
        end

        # Extract text from a content part
        # @param part [Hash] Content part with text
        # @return [String] Text content
        def extract_text_from_part(part)
          part[:text] || part['text'] || ''
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

          # Add image parts (order depends on provider)
          images = prompt_hash[:images] || prompt_hash['images'] || []
          images = [images] unless images.is_a?(Array)

          if images_before_text?
            # Anthropic recommends images before text
            images.each { |image| content_parts << format_image_part(image) }
            add_text_part(content_parts, prompt_hash)
          else
            # OpenAI/most others: text before images
            add_text_part(content_parts, prompt_hash)
            images.each { |image| content_parts << format_image_part(image) }
          end

          content_parts
        end

        # Add text part to content array if present
        # @param content_parts [Array] The content parts array
        # @param prompt_hash [Hash] Hash with :text key
        def add_text_part(content_parts, prompt_hash)
          return unless prompt_hash[:text] || prompt_hash['text']

          text = prompt_hash[:text] || prompt_hash['text']
          content_parts << { type: 'text', text: }
        end

        # Format an image into the appropriate API structure
        # This method should be overridden by clients that need different formats
        # @param image [String, Hash] Image URL or hash with url/detail keys
        # @return [Hash] Formatted image part for the API
        def format_image_part(image)
          case image
          when String
            format_image_url(image)
          when Hash
            format_image_hash(image)
          end
        end

        # Format a simple image URL string
        # Override this in subclasses for provider-specific format
        # @param url [String] Image URL
        # @return [Hash] Formatted image part
        def format_image_url(url)
          # Default: OpenAI format
          { type: 'image_url', image_url: { url: } }
        end

        # Format an image hash with url and optional detail
        # Override this in subclasses for provider-specific format
        # @param image_hash [Hash] Hash with url and optional detail keys
        # @return [Hash] Formatted image part
        def format_image_hash(image_hash)
          # Default: OpenAI format with detail support
          {
            type: 'image_url',
            image_url: {
              url: image_hash[:url] || image_hash['url'],
              detail: image_hash[:detail] || image_hash['detail']
            }.compact
          }
        end

        # Whether to place images before text in the content array
        # Override this in subclasses if needed (e.g., Anthropic recommends images first)
        # @return [Boolean] true if images should come before text
        def images_before_text?
          false
        end
      end
    end
  end
end
