# frozen_string_literal: true

module LlmConductor
  module Eval
    # Outcome of running ONE (input, model) pair through the engine.
    #
    # Ported from the Rails prototype's ModelRunner::Result struct, with the
    # +record_*+ fields renamed to +input_*+ and the on-disk +*_path+ fields
    # generalized to +*_ref+ (a Store handle — a filesystem path for FileStore,
    # an opaque key for InMemory).
    #
    # +status+ is one of: 'ok', 'parse_error', 'llm_error', 'exception'.
    Result = Struct.new(
      :input_id, :input_label, :model, :vendor, :status, :latency_ms,
      :input_tokens, :output_tokens, :total_tokens, :estimated_cost_usd,
      :parsed_score, :parsed_bucket, :extra_columns,
      :raw_output_ref, :parsed_output_ref, :error,
      keyword_init: true
    ) do
      # String-keyed hash for JSON manifest persistence.
      def to_h
        super.transform_keys(&:to_s)
      end

      def ok?
        status == 'ok'
      end
    end
  end
end
