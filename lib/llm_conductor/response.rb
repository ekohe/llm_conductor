# frozen_string_literal: true

module LlmConductor
  # Response object that encapsulates the result of LLM generation
  # with metadata like token usage and cost information
  class Response
    attr_reader :output, :input_tokens, :output_tokens, :metadata, :model

    def initialize(output:, model:, input_tokens: nil, output_tokens: nil, metadata: {})
      @output = output
      @model = model
      @input_tokens = input_tokens
      @output_tokens = output_tokens
      @metadata = metadata || {}
    end

    def total_tokens
      (@input_tokens || 0) + (@output_tokens || 0)
    end

    # Calculate estimated cost based on model and token usage
    def estimated_cost
      return nil unless valid_for_cost_calculation?

      pricing = model_pricing
      return nil unless pricing

      calculate_cost(pricing[:input_rate], pricing[:output_rate])
    end

    # Check if the response was successful
    def success?
      !@output.nil? && !@output.empty? && @metadata[:error].nil?
    end

    # Get metadata with cost included if available
    def metadata_with_cost
      cost = estimated_cost
      cost ? @metadata.merge(cost:) : @metadata
    end

    # Parse JSON from the output
    def parse_json
      return nil unless success? && @output

      JSON.parse(@output.strip)
    rescue JSON::ParserError => e
      raise JSON::ParserError, "Failed to parse JSON response: #{e.message}"
    end

    # Extract text between code blocks
    def extract_code_block(language = nil)
      return nil unless @output

      pattern = if language
                  /```#{Regexp.escape(language)}\s*(.*?)```/m
                else
                  /```(?:\w*)\s*(.*?)```/m
                end

      match = @output.match(pattern)
      match ? match[1].strip : nil
    end

    private

    def valid_for_cost_calculation?
      @model && total_tokens.positive?
    end

    def model_pricing
      case @model
      when /gpt-3\.5-turbo/
        { input_rate: 0.0000015, output_rate: 0.000002 }
      when /gpt-4o-mini/
        { input_rate: 0.000000150, output_rate: 0.0000006 }
      when /gpt-4/
        { input_rate: 0.00003, output_rate: 0.00006 }
      end
    end

    def calculate_cost(input_rate, output_rate)
      (@input_tokens || 0) * input_rate + (@output_tokens || 0) * output_rate
    end
  end
end
