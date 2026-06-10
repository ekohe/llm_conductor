# frozen_string_literal: true

module LlmConductor
  module Eval
    # Value object returned by a run. Holds the aggregated results and renders
    # CSV / markdown on demand. The caller decides whether to persist anything —
    # the engine never forces a filesystem layout on consumers.
    #
    # - +rows+         : Array of { model_result: Result, judge_verdict: Verdict }
    # - +summary+      : Array of per-model aggregate Hashes, best-quality first
    # - +needs_review+ : Array of Hashes for rows flagged for human eyeball
    Report = Struct.new(:rows, :summary, :needs_review, :csv_string, :markdown_string, keyword_init: true) do
      def to_csv
        csv_string
      end

      def to_markdown
        markdown_string
      end
    end
  end
end
