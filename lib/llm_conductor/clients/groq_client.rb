# frozen_string_literal: true

module LlmConductor
  module Clients
    # Groq client implementation for accessing Groq models via Groq API.
    #
    # The groq gem defaults to a 1024-token output cap and a 5s request timeout
    # (Groq::Configuration::DEFAULT_MAX_TOKENS / DEFAULT_REQUEST_TIMEOUT), which
    # silently truncate longer structured outputs mid-response. We raise both to
    # sane defaults and honor per-call +params+ (e.g. max_tokens, temperature).
    class GroqClient < BaseClient
      DEFAULT_MAX_TOKENS = 8192
      DEFAULT_REQUEST_TIMEOUT = 120

      private

      def generate_content(prompt)
        # Groq::Client.chat expects messages as positional arg, not keyword arg
        messages = [{ role: 'user', content: prompt }]
        options = { model_id: model }
        options[:max_tokens] = params[:max_tokens] if params[:max_tokens]
        options[:temperature] = params[:temperature] if params.key?(:temperature)
        client.chat(messages, **options)['content']
      end

      def client
        @client ||= begin
          config = LlmConductor.configuration.provider_config(:groq)
          Groq::Client.new(
            api_key: config[:api_key],
            max_tokens: config[:max_tokens] || DEFAULT_MAX_TOKENS,
            request_timeout: config[:request_timeout] || DEFAULT_REQUEST_TIMEOUT
          )
        end
      end
    end
  end
end
