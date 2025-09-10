# frozen_string_literal: true

require 'ostruct'

module LlmConductor
  module Prompts
    class BasePrompt
      attr_reader :data

      def initialize(data)
        @data = data.is_a?(Hash) ? OpenStruct.new(data) : data
      end

      def render
        raise NotImplementedError, 'Subclasses must implement render method'
      end

      protected

      def method_missing(method_name, *args, &block)
        if data.respond_to?(method_name)
          data.send(method_name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        data.respond_to?(method_name, include_private) || super
      end

      # Helper methods for common prompt patterns
      def format_list(items, bullet: '-')
        return '' if items.nil? || items.empty?
        
        Array(items).map { |item| "#{bullet} #{item}" }.join("\n")
      end

      def format_json_example(example_data)
        return '' unless example_data
        
        JSON.pretty_generate(example_data)
      end

      def truncate_text(text, max_length: 1000, suffix: '...')
        return '' unless text
        
        text = text.to_s
        return text if text.length <= max_length
        
        "#{text[0, max_length - suffix.length]}#{suffix}"
      end

      def escape_quotes(text)
        return '' unless text
        
        text.to_s.gsub('"', '\"')
      end
    end
  end
end
