# frozen_string_literal: true

require_relative 'result'

module LlmConductor
  module Eval
    # Runs one (input, model) pair through LlmConductor.generate, capturing
    # latency / tokens / cost / parse status and writing raw + parsed outputs
    # through the Store. Side-effect free — never touches the caller's data.
    #
    # All feature-specific behavior (prompt type, payload, parsing,
    # score/bucket extraction) is delegated to the Spec.
    class ModelRunner
      # Filesystem-safe slug for a model name (e.g. "gemini-2.5-flash").
      def self.slug(model)
        model.to_s.gsub(/[^A-Za-z0-9_.-]+/, '_')
      end

      def initialize(input, model:, vendor:, spec:, store:, run_id:, logger:, data: nil)
        @input = input
        @model = model
        @vendor = vendor.to_sym
        @spec = spec
        @store = store
        @run_id = run_id
        @logger = logger
        @data = data
      end

      def run
        input_id = @spec.input_id(@input)
        data = @data || @spec.build_data(@input)

        started_at = Time.now.utc
        response = LlmConductor.generate(**generate_args(data, input_id))
        latency_ms = ((Time.now.utc - started_at) * 1000).round

        raw_ref = @store.write_raw(@run_id, input_id, slug, response&.output.to_s)

        if response.nil? || !response.success?
          error = response&.metadata&.dig(:error) || 'LLM returned no response'
          return build_result(input_id:, status: 'llm_error', latency_ms:, response:, raw_ref:, error:)
        end

        parsed = @spec.parse(response.output)
        if parsed.nil?
          return build_result(input_id:, status: 'parse_error', latency_ms:, response:, raw_ref:,
                              error: 'LLM output not valid structured data')
        end

        parsed_ref = @store.write_parsed(@run_id, input_id, slug, parsed)
        build_result(input_id:, status: 'ok', latency_ms:, response:, raw_ref:, parsed_ref:, parsed:)
      rescue StandardError => e
        @logger.error("[Eval::ModelRunner] #{@model}@#{@spec.input_id(@input)}: #{e.class}: #{e.message}")
        Result.new(input_id: @spec.input_id(@input), input_label:, model: @model,
                   vendor: @vendor, status: 'exception', error: "#{e.class}: #{e.message}")
      end

      def slug
        self.class.slug(@model)
      end

      private

      def generate_args(data, input_id)
        args = { model: @model, vendor: @vendor }
        if @spec.prompt_type
          args[:type] = @spec.prompt_type
          args[:data] = data
        else
          args[:prompt] = data
        end
        params = @spec.vendor_params(vendor: @vendor, input_id:)
        args[:params] = params unless params.nil? || params.empty?
        args
      end

      def build_result(input_id:, status:, latency_ms:, response:, raw_ref:, parsed_ref: nil, parsed: nil, error: nil)
        summary = parsed ? @spec.output_summary(parsed) : { score: nil, bucket: nil }
        Result.new(
          input_id:, input_label:, model: @model, vendor: @vendor, status:, latency_ms:,
          input_tokens: response&.input_tokens, output_tokens: response&.output_tokens,
          total_tokens: response&.total_tokens, estimated_cost_usd: response&.estimated_cost,
          parsed_score: summary[:score], parsed_bucket: summary[:bucket],
          extra_columns: parsed ? @spec.extra_columns(parsed) : {},
          raw_output_ref: raw_ref, parsed_output_ref: parsed_ref, error:
        )
      end

      def input_label
        @spec.input_label(@input)
      end
    end
  end
end
