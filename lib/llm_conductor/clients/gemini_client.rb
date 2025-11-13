# frozen_string_literal: true

require 'gemini-ai'
require 'base64'
require 'net/http'
require 'uri'
require_relative 'concerns/vision_support'

module LlmConductor
  module Clients
    # Google Gemini client implementation for accessing Gemini models via Google AI API
    # Supports both text-only and multimodal (vision) requests
    class GeminiClient < BaseClient
      include Concerns::VisionSupport

      private

      def generate_content(prompt)
        content = format_content(prompt)
        parts = build_parts_for_gemini(content)

        payload = {
          contents: [
            { parts: }
          ]
        }

        response = client.generate_content(payload)
        response.dig('candidates', 0, 'content', 'parts', 0, 'text')
      end

      # Build parts array for Gemini API from formatted content
      # Converts VisionSupport format to Gemini's specific format
      # @param content [String, Array] Formatted content from VisionSupport
      # @return [Array] Array of parts in Gemini format
      def build_parts_for_gemini(content)
        case content
        when String
          [{ text: content }]
        when Array
          content.map { |part| convert_to_gemini_part(part) }
        else
          [{ text: content.to_s }]
        end
      end

      # Convert a VisionSupport formatted part to Gemini format
      # @param part [Hash] Content part with type and data
      # @return [Hash] Gemini-formatted part
      def convert_to_gemini_part(part)
        case part[:type]
        when 'text'
          { text: part[:text] }
        when 'image_url'
          convert_image_url_to_inline_data(part)
        when 'inline_data'
          part # Already in Gemini format
        else
          part
        end
      end

      # Convert image_url part to Gemini's inline_data format
      # @param part [Hash] Part with image_url
      # @return [Hash] Gemini inline_data format
      def convert_image_url_to_inline_data(part)
        url = part.dig(:image_url, :url)
        {
          inline_data: {
            mime_type: detect_mime_type(url),
            data: fetch_and_encode_image(url)
          }
        }
      end

      # Fetch image from URL and encode as base64
      # Gemini API requires images to be base64-encoded
      # @param url [String] Image URL
      # @return [String] Base64-encoded image data
      def fetch_and_encode_image(url)
        uri = URI.parse(url)
        response = fetch_image_from_uri(uri)

        raise StandardError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        Base64.strict_encode64(response.body)
      rescue StandardError => e
        raise StandardError, "Error fetching image from #{url}: #{e.message}"
      end

      # Fetch image from URI using Net::HTTP
      # @param uri [URI] Parsed URI
      # @return [Net::HTTPResponse] HTTP response
      def fetch_image_from_uri(uri)
        http = create_http_client(uri)
        request = Net::HTTP::Get.new(uri.request_uri)
        http.request(request)
      end

      # Create HTTP client with SSL configuration
      # @param uri [URI] Parsed URI
      # @return [Net::HTTP] Configured HTTP client
      def create_http_client(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        return http unless uri.scheme == 'https'

        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http
      end

      # Detect MIME type from URL file extension
      # @param url [String] Image URL
      # @return [String] MIME type (e.g., 'image/jpeg', 'image/png')
      def detect_mime_type(url)
        extension = File.extname(URI.parse(url).path).downcase
        case extension
        when '.jpg', '.jpeg' then 'image/jpeg'
        when '.png' then 'image/png'
        when '.gif' then 'image/gif'
        when '.webp' then 'image/webp'
        else 'image/jpeg' # Default to jpeg
        end
      end

      def client
        @client ||= begin
          config = LlmConductor.configuration.provider_config(:gemini)
          Gemini.new(
            credentials: {
              service: 'generative-language-api',
              api_key: config[:api_key]
            },
            options: { model: }
          )
        end
      end
    end
  end
end
