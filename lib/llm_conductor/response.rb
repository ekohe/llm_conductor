# frozen_string_literal: true

module LlmConductor
  class Response
    attr_reader :input, :output, :input_tokens, :output_tokens, :model, :vendor, :metadata

    def initialize(input:, output:, input_tokens: 0, output_tokens: 0, model: nil, vendor: nil, metadata: {})
      @input = input
      @output = output
      @input_tokens = input_tokens.to_i
      @output_tokens = output_tokens.to_i
      @model = model
      @vendor = vendor
      @metadata = metadata || {}
    end

    def total_tokens
      input_tokens + output_tokens
    end

    def success?
      !output.nil? && !output.to_s.strip.empty?
    end

    def to_h
      {
        input: input,
        output: output,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        total_tokens: total_tokens,
        model: model,
        vendor: vendor,
        metadata: metadata,
        success: success?
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    # Convenience methods for common output parsing
    def parse_json
      return nil unless output
      
      # Try to extract JSON from markdown code blocks first
      json_match = output.match(/```(?:json)?\s*(\{.*\})\s*```/m)
      json_string = json_match ? json_match[1] : output
      
      # Try to find JSON within other text
      if json_string == output && !json_string.strip.start_with?('{')
        json_match = output.match(/\{.*\}/m)
        json_string = json_match[0] if json_match
      end
      
      JSON.parse(json_string) if json_string
    rescue JSON::ParserError
      nil
    end

    def extract_urls
      return [] unless output
      
      output.scan(/https?:\/\/[^\s\]"']+/)
    end

    def extract_code_blocks(language = nil)
      return [] unless output
      
      if language
        output.scan(/```#{language}\s*(.*?)```/m).flatten
      else
        output.scan(/```(?:\w+)?\s*(.*?)```/m).flatten
      end
    end
  end
end
