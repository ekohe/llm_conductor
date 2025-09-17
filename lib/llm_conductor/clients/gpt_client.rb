# frozen_string_literal: true

module LlmConductor
  module Clients
    # OpenAI GPT client implementation for accessing GPT models via OpenAI API
    class GptClient < BaseClient
      private

      def generate_content(prompt)
        client.chat(parameters: { model:, messages: [{ role: 'user', content: prompt }] })
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
