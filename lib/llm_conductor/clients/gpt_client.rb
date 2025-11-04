# frozen_string_literal: true

require_relative 'concerns/vision_support'

module LlmConductor
  module Clients
    # OpenAI GPT client implementation for accessing GPT models via OpenAI API
    # Supports both text-only and multimodal (vision) requests
    class GptClient < BaseClient
      include Concerns::VisionSupport

      private

      def generate_content(prompt)
        content = format_content(prompt)
        client.chat(parameters: { model:, messages: [{ role: 'user', content: }] })
              .dig('choices', 0, 'message', 'content')
      end

      def client
        @client ||= begin
          config = LlmConductor.configuration.provider_config(:openai)
          options = { access_token: config[:api_key] }
          options[:organization_id] = config[:organization] if config[:organization]
          OpenAI::Client.new(options)
        end
      end
    end
  end
end
