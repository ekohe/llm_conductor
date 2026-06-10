# frozen_string_literal: true

require 'logger'
require 'time'

require 'llm_conductor'

require_relative 'eval/json_parser'
require_relative 'eval/result'
require_relative 'eval/verdict'
require_relative 'eval/spec'
require_relative 'eval/store/base'
require_relative 'eval/store/in_memory'
require_relative 'eval/store/file_store'
require_relative 'eval/model_runner'
require_relative 'eval/judge'
require_relative 'eval/report'
require_relative 'eval/report_builder'
require_relative 'eval/runner'

module LlmConductor
  # Opt-in model-evaluation harness. `require 'llm_conductor/eval'` to load it;
  # core `require 'llm_conductor'` users pay nothing.
  #
  # Runs the same prompt across N (model, vendor) pairs over M caller-supplied
  # inputs, then compares them on cost, latency, tokens, and LLM-judged quality.
  # The engine is feature-agnostic; everything feature-specific lives in a Spec.
  #
  #   require 'llm_conductor/eval'
  #
  #   report = LlmConductor::Eval.run(
  #     spec:   MyFeatureSpec.new,
  #     inputs: my_inputs,                       # any enumerable; engine never selects/queries
  #     models: [{ model: 'gpt-4o-mini', vendor: :openai },
  #              { model: 'gemini-2.5-flash', vendor: :gemini }],
  #     judge:  { model: 'llama-3.3-70b-versatile', vendor: :groq }
  #   )
  #   report.summary       # per-model aggregates
  #   report.to_markdown   # decision-aid report (caller persists)
  #   report.to_csv        # per-row data
  #   report.needs_review  # rows flagged for human eyeball
  module Eval
    module_function

    # The single entrypoint. +spec+ implements Eval::Spec; +inputs+ is any
    # enumerable of opaque objects the spec knows how to interpret; +models+ is
    # the caller-owned list of { model:, vendor: } candidate pairs.
    def run(spec:, inputs:, models:, judge: {}, store: nil, logger: nil, run_id: nil)
      Runner.new(
        spec:, inputs:, models:, judge:,
        store: store || Store::InMemory.new,
        logger: logger || default_logger,
        run_id: run_id || generate_run_id
      ).run
    end

    # Re-judge stored candidate outputs without recalling the candidate models.
    def judge_only(run_id:, spec:, store:, judge: {}, logger: nil)
      Runner.judge_only(run_id:, spec:, store:, judge:, logger: logger || default_logger)
    end

    # Rebuild the Report from a stored manifest, no model or judge calls.
    def report_only(run_id:, spec:, store:)
      Runner.report_only(run_id:, spec:, store:)
    end

    def default_logger
      LlmConductor.configuration.logger || Logger.new($stdout)
    end

    def generate_run_id
      "run_#{Time.now.utc.strftime('%Y%m%d_%H%M%S')}"
    end
  end
end
