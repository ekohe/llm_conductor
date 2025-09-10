# frozen_string_literal: true

module LlmConductor
  module Integrations
    module Rails
      extend ActiveSupport::Concern

      included do
        # Add logging if Rails is available
        if defined?(::Rails)
          before_action :log_llm_request, if: -> { respond_to?(:log_llm_request, true) }
          after_action :log_llm_response, if: -> { respond_to?(:log_llm_response, true) }
        end
      end

      class_methods do
        def llm_client(model: nil, type: nil, vendor: nil, **options)
          model ||= LlmConductor.configuration.default_model
          
          LlmConductor.client(
            model: model,
            type: type,
            vendor: vendor,
            **options
          )
        end
      end

      private

      def log_llm_request
        return unless defined?(::Rails) && ::Rails.logger
        
        ::Rails.logger.info "[LLM] Starting request - Model: #{params[:model] || 'default'}, Type: #{params[:type]}"
      end

      def log_llm_response
        return unless defined?(::Rails) && ::Rails.logger && @llm_response
        
        ::Rails.logger.info "[LLM] Request completed - Tokens: #{@llm_response.total_tokens}, Success: #{@llm_response.success?}"
      end

      def handle_llm_error(error, fallback_response = nil)
        if defined?(NewRelic)
          NewRelic::Agent.notice_error(error)
        end

        if defined?(::Rails) && ::Rails.logger
          ::Rails.logger.error "[LLM] Error: #{error.message}"
          ::Rails.logger.error error.backtrace.join("\n") if error.backtrace
        end

        fallback_response || { error: 'Language model request failed' }
      end
    end

    # Sidekiq integration
    class SidekiqWorker
      include Sidekiq::Worker

      def perform(model, data, type = nil, options = {})
        client = LlmConductor.client(
          model: model,
          type: type&.to_sym,
          **options.symbolize_keys
        )

        response = client.generate(data: data)
        
        # Store or process the response as needed
        process_response(response)
        
        response.to_h
      end

      private

      def process_response(response)
        # Override in subclasses to handle the response
        # e.g., save to database, trigger callbacks, etc.
      end
    end
  end
end
