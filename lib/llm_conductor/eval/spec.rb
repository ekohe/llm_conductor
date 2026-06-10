# frozen_string_literal: true

require_relative 'json_parser'

module LlmConductor
  module Eval
    # The public extension seam. Subclass (or duck-type) this to describe how to
    # evaluate one LLM-powered feature: how to turn a caller-supplied input into
    # a prompt payload, how to parse the output, and what the judge should grade.
    #
    # The engine itself is generic and feature-agnostic; everything
    # feature-specific lives here. Unlike the Rails prototype's Feature::Base,
    # there is no +select_cases+ — selecting which inputs to evaluate is the
    # caller's job, done before calling LlmConductor::Eval.run and passed via
    # +inputs:+. The engine never queries a database.
    class Spec
      # Symbol passed to LlmConductor.generate as +type:+ (must match a
      # registered prompt). Return nil if instead you build a full prompt
      # string in #build_data, in which case the engine passes it as +prompt:+.
      def prompt_type
        raise NotImplementedError
      end

      # Stable id for an input (was record.id). Used for output grouping/paths.
      def input_id(_input)
        raise NotImplementedError
      end

      # Human label for an input (was record.name). Defaults to the id.
      def input_label(input)
        input_id(input).to_s
      end

      # Build the prompt payload for one input. When #prompt_type is set this is
      # passed as +data:+; otherwise it must be a full prompt String passed as
      # +prompt:+ (was build_data(record)).
      def build_data(_input)
        raise NotImplementedError
      end

      # Parse the LLM's raw text into a Hash, or nil on failure. Defaults to the
      # gem's conservative JsonParser; override for tuned/feature-specific parsing.
      def parse(raw)
        JsonParser.parse(raw)
      end

      # Vendor-specific generation params (e.g. a deterministic Ollama seed).
      # Return {} for vendors that don't expose one.
      # rubocop:disable Lint/UnusedMethodArgument
      def vendor_params(vendor:, input_id:)
        {}
      end
      # rubocop:enable Lint/UnusedMethodArgument

      # { score: Numeric|nil, bucket: String|nil } — powers CSV columns and the
      # bucket-disagreement detection. +bucket+ may be any discrete label.
      def output_summary(_parsed)
        raise NotImplementedError
      end

      # Text inlined into the judge prompt describing the rubric the candidate
      # was asked to follow.
      def judge_rubric_excerpt
        raise NotImplementedError
      end

      # [{ key:, description: }] — dimensions the judge scores 0-100 each.
      def judge_dimensions
        raise NotImplementedError
      end

      # Extra per-row CSV columns beyond the base set. Keys become headers.
      def extra_columns(_parsed)
        {}
      end
    end
  end
end
