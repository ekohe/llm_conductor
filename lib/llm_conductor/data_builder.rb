# frozen_string_literal: true

module LlmConductor
  # Base class for building structured data from source objects for LLM consumption.
  # Provides helper methods for data extraction, formatting, and safe handling of nested data.
  #
  # @example Basic usage
  #   class CompanyDataBuilder < LlmConductor::DataBuilder
  #     def build
  #       {
  #         id: source_object.id,
  #         name: source_object.name,
  #         metrics: build_metrics
  #       }
  #     end
  #
  #     private
  #
  #     def build_metrics
  #       {
  #         employees: safe_extract(:employee_count, default: 'Unknown')
  #       }
  #     end
  #   end
  #
  #   builder = CompanyDataBuilder.new(company)
  #   data = builder.build
  class DataBuilder
    attr_reader :source_object

    def initialize(source_object)
      @source_object = source_object
    end

    # Abstract method to be implemented by subclasses
    # @return [Hash] The built data structure
    def build
      raise NotImplementedError, "#{self.class} must implement the #build method"
    end

    protected

    # Safely extract a value from the source object with a default fallback
    # @param attribute [Symbol, String] The attribute name to extract
    # @param default [Object] Default value if extraction fails
    # @return [Object] The extracted value or default
    def safe_extract(attribute, default: nil)
      return default if source_object.nil?

      if source_object.respond_to?(attribute)
        value = source_object.public_send(attribute)
        value.nil? || (value.respond_to?(:empty?) && value.empty?) ? default : value
      else
        default
      end
    end

    # Extract nested data from a hash-like structure
    # @param root_key [Symbol, String] The root key to start extraction from
    # @param *path [Array<String, Symbol>] The path to navigate through nested structures
    # @return [Object, nil] The extracted value or nil if not found
    def extract_nested_data(root_key, *path)
      return nil if source_object.nil?

      data = safe_extract(root_key)
      return nil unless hash_like?(data)

      navigate_nested_path(data, path)
    rescue StandardError
      nil
    end

    # Format a value for LLM consumption with appropriate fallbacks
    # @param value [Object] The value to format
    # @param options [Hash] Formatting options
    # @option options [String] :default ('N/A') Default value for nil/empty values
    # @option options [String] :prefix ('') Prefix to add to non-empty values
    # @option options [String] :suffix ('') Suffix to add to non-empty values
    # @option options [Integer] :max_length (nil) Maximum length to truncate to
    # @return [String] Formatted value suitable for LLM consumption
    def format_for_llm(value, options = {})
      default = options.fetch(:default, 'N/A')
      prefix = options.fetch(:prefix, '')
      suffix = options.fetch(:suffix, '')
      max_length = options[:max_length]

      # Handle nil or empty values
      return default if value.nil? || (value.respond_to?(:empty?) && value.empty?)

      # Convert to string and apply formatting
      formatted = "#{prefix}#{value}#{suffix}"

      # Apply length limit if specified
      formatted = "#{formatted[0...max_length]}..." if max_length && formatted.length > max_length

      formatted
    end

    # Extract and format a list of items
    # @param attribute [Symbol, String] The attribute containing the list
    # @param options [Hash] Formatting options
    # @option options [String] :separator (', ') Separator for joining items
    # @option options [Integer] :limit (nil) Maximum number of items to include
    # @option options [String] :default ('None') Default value for empty lists
    # @return [String] Formatted list suitable for LLM consumption
    def extract_list(attribute, options = {})
      separator = options.fetch(:separator, ', ')
      limit = options[:limit]
      default = options.fetch(:default, 'None')

      items = safe_extract(attribute, default: [])
      return default unless items.respond_to?(:map) && !items.empty?

      # Apply limit if specified
      items = items.first(limit) if limit

      items.map(&:to_s).join(separator)
    end

    # Build a summary string from multiple attributes
    # @param attributes [Array<Symbol>] List of attributes to include
    # @param options [Hash] Formatting options
    # @option options [String] :separator (' | ') Separator between attributes
    # @option options [Boolean] :skip_empty (true) Whether to skip empty values
    # @return [String] Combined summary string
    def build_summary(*attributes, **options)
      separator = options.fetch(:separator, ' | ')
      skip_empty = options.fetch(:skip_empty, true)

      parts = attributes.map do |attr|
        value = safe_extract(attr)
        next if skip_empty && (value.nil? || (value.respond_to?(:empty?) && value.empty?))

        format_for_llm(value)
      end.compact

      parts.join(separator)
    end

    # Helper method to safely convert numeric values with formatting
    # @param value [Numeric, String] The value to format
    # @param options [Hash] Formatting options
    # @option options [String] :currency ('$') Currency symbol for monetary values
    # @option options [Boolean] :as_currency (false) Whether to format as currency
    # @option options [Integer] :precision (0) Decimal precision
    # @return [String] Formatted numeric value
    def format_number(value, options = {})
      return format_for_llm(nil, options) if value.nil?

      begin
        numeric_value = Float(value)
        formatted = format_numeric_value(numeric_value, options[:precision] || 0)
        formatted = add_thousands_separators(formatted)

        apply_currency_formatting(formatted, options)
      rescue ArgumentError
        format_for_llm(value, options)
      end
    end

    private

    # Helper to check if an object has a specific method
    def attribute?(attribute)
      source_object&.respond_to?(attribute)
    end

    # Check if data structure supports hash-like access
    def hash_like?(data)
      data.respond_to?(:[])
    end

    # Navigate through nested hash path
    def navigate_nested_path(data, path)
      path.reduce(data) do |current_data, key|
        return nil unless hash_like?(current_data)

        find_key_variant(current_data, key)
      end
    end

    # Find key in various formats (string, symbol)
    def find_key_variant(data, key)
      data[key] || data[key.to_s] || data[key.to_sym]
    end

    # Format numeric value with precision
    def format_numeric_value(numeric_value, precision)
      if precision.positive?
        format("%.#{precision}f", numeric_value)
      else
        numeric_value.to_i.to_s
      end
    end

    # Add thousands separators to numeric string
    def add_thousands_separators(formatted)
      formatted.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    # Apply currency formatting if requested
    def apply_currency_formatting(formatted, options)
      if options.fetch(:as_currency, false)
        currency = options.fetch(:currency, '$')
        "#{currency}#{formatted}"
      else
        formatted
      end
    end
  end
end
