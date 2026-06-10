# frozen_string_literal: true

require 'csv'
require_relative 'verdict'
require_relative 'report'

module LlmConductor
  module Eval
    # Pure aggregation: turns a run's per-(input, model) rows into a Report
    # (CSV string + decision-aid markdown + per-model summary + needs-review
    # list). Unlike the Rails prototype's ReportBuilder it writes no files;
    # persistence is the caller's / Store's job.
    #
    # +rows+ is an Array of { model_result: Result, judge_verdict: Verdict }.
    class ReportBuilder
      BASE_CSV_COLUMNS = %w[
        input_id input_label model vendor status
        latency_ms input_tokens output_tokens total_tokens estimated_cost_usd
        parsed_score parsed_bucket
        judge_quality_score
      ].freeze

      JUDGE_TAIL_COLUMNS = %w[
        judge_verdict_one_line judge_issues judge_error
        self_judge needs_human_review review_reasons
        raw_output_ref parsed_output_ref error
      ].freeze

      def initialize(rows:, run_id:, judge_model:, spec:)
        @rows = rows
        @run_id = run_id
        @judge_model = judge_model
        @spec = spec
      end

      def build
        bucket_disagreement = compute_bucket_disagreement
        summary = build_summary
        Report.new(
          rows: @rows,
          summary:,
          needs_review: build_needs_review(bucket_disagreement),
          csv_string: build_csv(bucket_disagreement),
          markdown_string: build_markdown(bucket_disagreement, summary)
        )
      end

      private

      attr_reader :rows, :run_id, :judge_model, :spec

      def judge_dimension_columns
        @judge_dimension_columns ||= spec.judge_dimensions.map { |d| "judge_#{d[:key]}" }
      end

      def extra_csv_keys
        @extra_csv_keys ||= rows.flat_map { |r| (r[:model_result].extra_columns || {}).keys }.uniq
      end

      def csv_columns
        BASE_CSV_COLUMNS + judge_dimension_columns + JUDGE_TAIL_COLUMNS + extra_csv_keys
      end

      def compute_bucket_disagreement
        by_input = Hash.new { |h, k| h[k] = Set.new }
        rows.each do |row|
          mr = row[:model_result]
          next unless mr.status == 'ok' && mr.parsed_bucket

          by_input[mr.input_id] << mr.parsed_bucket
        end
        by_input.transform_values { |set| set.size > 1 ? set.sort : [] }
      end

      def build_csv(bucket_disagreement)
        columns = csv_columns
        CSV.generate(write_headers: true, headers: columns) do |csv|
          rows.each { |row| csv << csv_row(row, bucket_disagreement, columns) }
        end
      end

      def csv_row(row, bucket_disagreement, columns)
        mr = row[:model_result]
        jv = row[:judge_verdict]
        base = base_csv_values(mr, jv, flag_reasons(mr, jv, bucket_disagreement))
        spec.judge_dimensions.each { |d| base["judge_#{d[:key]}"] = jv&.dimensions&.dig(d[:key]) }
        (mr.extra_columns || {}).each { |k, v| base[k] = v }
        columns.map { |c| base[c] }
      end

      def base_csv_values(result, verdict, review_reasons)
        {
          'input_id' => result.input_id, 'input_label' => result.input_label, 'model' => result.model,
          'vendor' => result.vendor, 'status' => result.status, 'latency_ms' => result.latency_ms,
          'input_tokens' => result.input_tokens, 'output_tokens' => result.output_tokens,
          'total_tokens' => result.total_tokens, 'estimated_cost_usd' => result.estimated_cost_usd,
          'parsed_score' => result.parsed_score, 'parsed_bucket' => result.parsed_bucket,
          'judge_quality_score' => verdict&.quality_score, 'judge_verdict_one_line' => verdict&.verdict_one_line,
          'judge_issues' => Array(verdict&.issues).join(' | '), 'judge_error' => verdict&.judge_error,
          'self_judge' => (result.model == judge_model), 'needs_human_review' => review_reasons.any?,
          'review_reasons' => review_reasons.join('; '), 'raw_output_ref' => result.raw_output_ref,
          'parsed_output_ref' => result.parsed_output_ref, 'error' => result.error
        }
      end

      def build_needs_review(bucket_disagreement)
        rows.filter_map do |row|
          mr = row[:model_result]
          reasons = flag_reasons(mr, row[:judge_verdict], bucket_disagreement)
          next if reasons.empty?

          { input_id: mr.input_id, input_label: mr.input_label, model: mr.model, reasons: }
        end
      end

      def flag_reasons(result, verdict, bucket_disagreement)
        reasons = []
        disagree = bucket_disagreement[result.input_id]
        reasons << "buckets_disagree(#{disagree.join(',')})" if disagree&.any?
        reasons << 'judge_borderline' if verdict && Verdict.borderline?(verdict.quality_score)
        reasons << 'parse_failed' if result.status == 'parse_error'
        reasons << 'llm_error' if result.status == 'llm_error'
        reasons
      end

      def build_summary
        rows.group_by { |r| r[:model_result].model }
            .map { |model, model_rows| summarize_model(model, model_rows) }
            .sort_by { |s| -(s[:mean_quality] || -1) }
      end

      def summarize_model(model, model_rows)
        ok = model_rows.count { |r| r[:model_result].status == 'ok' }
        latencies = model_rows.filter_map { |r| r[:model_result].latency_ms }
        costs = model_rows.filter_map { |r| r[:model_result].estimated_cost_usd }.map(&:to_f)
        qualities = model_rows.filter_map { |r| r[:judge_verdict]&.quality_score }
        {
          model:, parse_ok_pct: pct(ok, model_rows.size), mean_quality: mean(qualities)&.round(1),
          median_latency_ms: percentile(latencies, 50), p95_latency_ms: percentile(latencies, 95),
          mean_cost: costs.empty? ? 0.0 : (costs.sum / costs.size).round(5), total_cost: costs.sum.round(4),
          review_pct: pct(review_count(model_rows), model_rows.size)
        }
      end

      def review_count(model_rows)
        model_rows.count do |r|
          jv = r[:judge_verdict]
          r[:model_result].status != 'ok' || (jv && Verdict.borderline?(jv.quality_score))
        end
      end

      def build_markdown(bucket_disagreement, summary)
        <<~MD
          # LLM Eval — #{run_id}

          - Inputs in this run: **#{rows.map { |r| r[:model_result].input_id }.uniq.size}**
          - Candidate models: **#{summary.size}**
          - Judge model: `#{judge_model}` (rows where the judged model == judge model are flagged `self_judge`)

          ## Per-model summary

          | Model | Parse OK% | Mean Judge | Median latency | P95 latency | Mean cost | Total cost | % needs review |
          |---|---:|---:|---:|---:|---:|---:|---:|
          #{summary.map { |s| markdown_summary_row(s) }.join("\n")}

          ## Recommendation buckets per input

          #{bucket_table}

          ## Bucket-disagreement cases (model choice matters here)

          #{bucket_disagreement_section(bucket_disagreement)}

          ## Pareto picks

          #{pareto_section(summary)}
        MD
      end

      def markdown_summary_row(summary)
        "| `#{summary[:model]}` | #{summary[:parse_ok_pct]}% | #{summary[:mean_quality] || 'n/a'} | " \
          "#{summary[:median_latency_ms] || 'n/a'}ms | #{summary[:p95_latency_ms] || 'n/a'}ms | " \
          "$#{format('%.5f', summary[:mean_cost])} | $#{format('%.4f', summary[:total_cost])} | " \
          "#{summary[:review_pct]}% |"
      end

      def bucket_table
        lines = ['| Input | Model | Bucket | Score | Judge | Status |', '|---|---|---|---:|---:|---|']
        rows.group_by { |r| r[:model_result].input_id }.each do |input_id, input_rows|
          label = input_rows.first[:model_result].input_label
          input_rows.each do |r|
            mr = r[:model_result]
            jv = r[:judge_verdict]
            lines << "| #{input_id} #{label} | `#{mr.model}` | #{mr.parsed_bucket || '-'} | " \
                     "#{mr.parsed_score || '-'} | #{jv&.quality_score || '-'} | #{mr.status} |"
          end
        end
        lines.join("\n")
      end

      def bucket_disagreement_section(bucket_disagreement)
        cases = bucket_disagreement.reject { |_, v| v.empty? }
        return '_None — every input received the same bucket across all models._' if cases.empty?

        cases.flat_map { |input_id, buckets| disagreement_block(input_id, buckets) }.join("\n")
      end

      def disagreement_block(input_id, buckets)
        input_rows = rows.select { |r| r[:model_result].input_id == input_id && r[:model_result].status == 'ok' }
        return [] if input_rows.empty?

        label = input_rows.first[:model_result].input_label
        lines = ["### #{input_id} — #{label}", '', "Buckets seen: **#{buckets.join(', ')}**", '',
                 '| Model | Bucket | Score | Judge |', '|---|---|---:|---:|']
        input_rows.each do |r|
          mr = r[:model_result]
          jv = r[:judge_verdict]
          lines << "| `#{mr.model}` | #{mr.parsed_bucket || '-'} | #{mr.parsed_score || '-'} | #{jv&.quality_score || '-'} |"
        end
        lines << ''
        lines
      end

      def pareto_section(summary)
        return '_No successful runs to rank._' if summary.empty?

        lines = ['Top 3 by mean judge quality:', '']
        summary.first(3).each_with_index do |s, i|
          lines << "#{i + 1}. **`#{s[:model]}`** — judge **#{s[:mean_quality] || 'n/a'}**, " \
                   "median **#{s[:median_latency_ms]}ms**, mean cost **$#{format('%.5f', s[:mean_cost])}**, " \
                   "parse OK **#{s[:parse_ok_pct]}%**."
        end
        lines << ''
        lines << '_Rows flagged `needs_human_review=true` are the ones to sanity-check manually._'
        lines.join("\n")
      end

      def pct(num, den)
        return 0 if den.zero?

        ((num.to_f / den) * 100).round(1)
      end

      def mean(values)
        return nil if values.empty?

        values.sum.to_f / values.size
      end

      def percentile(values, target_pct)
        return nil if values.empty?

        sorted = values.sort
        sorted[((target_pct / 100.0) * (sorted.size - 1)).round]
      end
    end
  end
end
