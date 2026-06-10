# frozen_string_literal: true

module LlmConductor
  module Eval
    # Scores in this range are "borderline" — the judge is uncertain enough that
    # the row is flagged for human review. Tuned in the Rails prototype.
    BORDERLINE_RANGE = (50..70)

    # The LLM-as-judge's verdict for one candidate (input, model) output.
    # Ported verbatim from the prototype's Judge::Verdict struct.
    Verdict = Struct.new(
      :quality_score, :dimensions, :issues, :verdict_one_line,
      :judge_model, :judge_latency_ms, :judge_input_tokens, :judge_output_tokens,
      :judge_estimated_cost_usd, :judge_error,
      keyword_init: true
    ) do
      # String-keyed hash for JSON manifest persistence.
      def to_h
        super.transform_keys(&:to_s)
      end

      def borderline?
        Verdict.borderline?(quality_score)
      end

      def self.borderline?(score)
        score.is_a?(Numeric) && BORDERLINE_RANGE.cover?(score)
      end
    end
  end
end
