# frozen_string_literal: true

require 'time'
require_relative 'model_runner'
require_relative 'judge'
require_relative 'report_builder'
require_relative 'result'
require_relative 'verdict'

module LlmConductor
  module Eval
    # Top-level orchestrator. For each input, builds the prompt data once, runs
    # every candidate (input, model) pair through ModelRunner, judges it, and
    # rewrites the manifest after each pair so the run stays resumable /
    # reportable mid-flight.
    #
    # Unlike the Rails prototype it does NO data selection — the caller passes
    # +inputs:+ directly. See LlmConductor::Eval.run for the public entrypoint.
    class Runner
      def initialize(spec:, inputs:, models:, judge:, store:, logger:, run_id:)
        @spec = spec
        @inputs = inputs.to_a
        @models = models
        @judge_config = self.class.normalize_judge(judge)
        @store = store
        @logger = logger
        @run_id = run_id
      end

      def run
        @logger.info("LLM eval run=#{@run_id} models=#{@models.map { |m| m[:model] }.join(',')} " \
                     "judge=#{@judge_config[:model]}")
        warn_self_judge
        manifest = base_manifest
        rows = run_all_pairs(manifest)
        manifest[:finished_at] = Time.now.utc.iso8601
        @store.write_manifest(@run_id, manifest)
        build_report(rows)
      end

      # Rebuild a Report from a stored manifest without recalling models or judge.
      def self.report_only(run_id:, spec:, store:)
        manifest = store.read_manifest(run_id) or raise ArgumentError, "No manifest for run_id=#{run_id}"
        rows = manifest['rows'].map { |raw| restore_row(raw) }
        ReportBuilder.new(rows:, run_id:, judge_model: manifest['judge_model'], spec:).build
      end

      # Re-run the judge against stored candidate outputs (e.g. after changing
      # the judge model). Fully self-contained: input data is read from the store.
      def self.judge_only(run_id:, spec:, store:, judge:, logger:)
        config = normalize_judge(judge)
        manifest = store.read_manifest(run_id) or raise ArgumentError, "No manifest for run_id=#{run_id}"
        judge_obj = Judge.new(spec:, store:, run_id:, logger:,
                              judge_model: config[:model], judge_vendor: config[:vendor])
        rows = manifest['rows'].map { |raw| rejudge_row(raw, judge_obj, store, run_id) }
        manifest['judge_model'] = config[:model]
        manifest['rejudged_at'] = Time.now.utc.iso8601
        store.write_manifest(run_id, manifest)
        ReportBuilder.new(rows:, run_id:, judge_model: config[:model], spec:).build
      end

      def self.normalize_judge(judge)
        judge ||= {}
        { model: judge[:model] || Judge::DEFAULT_MODEL,
          vendor: (judge[:vendor] || Judge::DEFAULT_VENDOR).to_sym }
      end

      def self.restore_result(raw)
        Result.new(**raw.transform_keys(&:to_sym))
      end

      def self.restore_verdict(raw)
        raw ? Verdict.new(**raw.transform_keys(&:to_sym)) : nil
      end

      def self.restore_row(raw)
        { model_result: restore_result(raw['model_result']),
          judge_verdict: restore_verdict(raw['judge_verdict']) }
      end

      def self.rejudge_row(raw, judge_obj, store, run_id)
        result = restore_result(raw['model_result'])
        input_data = store.read_input_data(run_id, result.input_id)
        verdict = judge_obj.judge(model_result: result, input_data:)
        raw['judge_verdict'] = verdict&.to_h
        { model_result: result, judge_verdict: verdict }
      end

      private

      def run_all_pairs(manifest)
        rows = []
        @inputs.each_with_index do |input, idx|
          input_id = @spec.input_id(input)
          data = @spec.build_data(input)
          @store.write_input_data(@run_id, input_id, data)
          @models.each do |cand|
            row = run_pair(input, data, cand)
            rows << row
            manifest[:rows] << serialize_row(row)
            @store.write_manifest(@run_id, manifest)
            log_pair(idx, cand, row)
          end
        end
        rows
      end

      def run_pair(input, data, cand)
        result = ModelRunner.new(input, model: cand[:model], vendor: cand[:vendor], spec: @spec,
                                        store: @store, run_id: @run_id, logger: @logger, data:).run
        verdict = build_judge.judge(model_result: result, input_data: data)
        { model_result: result, judge_verdict: verdict }
      end

      def build_judge
        Judge.new(spec: @spec, store: @store, run_id: @run_id, logger: @logger,
                  judge_model: @judge_config[:model], judge_vendor: @judge_config[:vendor])
      end

      def base_manifest
        { run_id: @run_id, started_at: Time.now.utc.iso8601, judge_model: @judge_config[:model],
          models: @models, rows: [] }
      end

      def serialize_row(row)
        { 'model_result' => row[:model_result].to_h, 'judge_verdict' => row[:judge_verdict]&.to_h }
      end

      def build_report(rows)
        ReportBuilder.new(rows:, run_id: @run_id, judge_model: @judge_config[:model], spec: @spec).build
      end

      def warn_self_judge
        return unless @models.any? { |m| m[:model] == @judge_config[:model] }

        @logger.warn("[Eval] judge model #{@judge_config[:model]} also appears in candidates — " \
                     'those rows will be flagged self_judge=true and should be discounted when ranking.')
      end

      def log_pair(idx, cand, row)
        result = row[:model_result]
        verdict = row[:judge_verdict]
        @logger.info("  [#{idx + 1}/#{@inputs.size}] #{cand[:model]} -> status=#{result.status} " \
                     "latency=#{result.latency_ms}ms judge=#{verdict&.quality_score}")
      end
    end
  end
end
