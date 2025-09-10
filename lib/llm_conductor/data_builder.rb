# frozen_string_literal: true

module LlmConductor
  class DataBuilder
    attr_reader :source_object, :options

    def initialize(source_object, **options)
      @source_object = source_object
      @options = options
    end

    def build
      raise NotImplementedError, 'Subclasses must implement build method'
    end

    protected

    # Helper methods for common data extraction patterns
    def extract_attributes(*attributes)
      attributes.each_with_object({}) do |attr, result|
        if source_object.respond_to?(attr)
          result[attr] = source_object.send(attr)
        end
      end
    end

    def extract_nested_data(hash_key, *nested_keys)
      return {} unless source_object.respond_to?(hash_key)
      
      data = source_object.send(hash_key) || {}
      return {} unless data.is_a?(Hash)

      nested_keys.each_with_object({}) do |key, result|
        result[key] = data[key.to_s] || data[key.to_sym]
      end
    end

    def safe_extract(method_name, default: nil)
      if source_object.respond_to?(method_name)
        source_object.send(method_name) || default
      else
        default
      end
    end

    def format_for_llm(value)
      case value
      when nil
        'Not available'
      when Array
        value.compact.join(', ')
      when Hash
        value.compact.to_json
      else
        value.to_s
      end
    end
  end
end
