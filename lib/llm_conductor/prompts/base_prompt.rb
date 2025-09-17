# frozen_string_literal: true

module LlmConductor
  module Prompts
    # Base class for all prompt templates
    # Provides common functionality and data access patterns
    class BasePrompt
      attr_reader :data

      def initialize(data = {})
        @data = data || {}
        setup_data_methods
      end

      # Override this method in subclasses to define the prompt
      def render
        raise NotImplementedError, 'Subclasses must implement #render method'
      end

      # Get the rendered prompt as a string
      def to_s
        render.strip
      end

      # Safe access to nested hash values
      def data_dig(*keys)
        @data.dig(*keys) if @data.respond_to?(:dig)
      end

      # Convenience alias for data_dig
      alias dig data_dig

      protected

      # Truncate text to a maximum length with ellipsis
      def truncate_text(text, max_length: 100)
        return '' if text.nil?

        text = text.to_s
        return text if text.length <= max_length

        "#{text[0...max_length]}..."
      end

      # Format a list as a numbered list
      def numbered_list(items)
        return '' if items.nil? || items.empty?

        items.map.with_index(1) { |item, index| "#{index}. #{item}" }.join("\n")
      end

      # Format a list as a bulleted list
      def bulleted_list(items)
        return '' if items.nil? || items.empty?

        items.map { |item| "• #{item}" }.join("\n")
      end

      private

      # Create dynamic method accessors for data keys
      def setup_data_methods
        return unless @data.respond_to?(:each)

        @data.each do |key, value|
          next unless key.respond_to?(:to_sym)

          define_singleton_method(key.to_sym) { value }
        end
      end

      # Handle missing methods by checking data hash
      def method_missing(method_name, *args, &block)
        if @data.respond_to?(:[]) && @data.key?(method_name)
          @data[method_name]
        elsif @data.respond_to?(:[]) && @data.key?(method_name.to_s)
          @data[method_name.to_s]
        else
          super
        end
      end

      # Support for respond_to? with dynamic methods
      def respond_to_missing?(method_name, include_private = false)
        (@data.respond_to?(:[]) &&
         (@data.key?(method_name) || @data.key?(method_name.to_s))) || super
      end
    end
  end
end
