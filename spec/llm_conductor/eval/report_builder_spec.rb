# frozen_string_literal: true

require 'csv'
require_relative 'support'

RSpec.describe LlmConductor::Eval::ReportBuilder do
  let(:spec) { EvalSpecSupport::SampleSpec.new }

  def result(input_id:, model:, bucket:, score: 80, status: 'ok', latency: 100, cost: 0.01) # rubocop:disable Metrics/ParameterLists
    LlmConductor::Eval::Result.new(
      input_id:, input_label: "label#{input_id}", model:, vendor: :openai, status:,
      latency_ms: latency, input_tokens: 10, output_tokens: 20, total_tokens: 30,
      estimated_cost_usd: cost, parsed_score: score, parsed_bucket: bucket,
      extra_columns: { 'summary' => 'a summary' }
    )
  end

  def verdict(quality:, accuracy: 80, clarity: 80)
    LlmConductor::Eval::Verdict.new(
      quality_score: quality, dimensions: { 'accuracy' => accuracy, 'clarity' => clarity },
      issues: ['nit'], verdict_one_line: 'ok', judge_model: 'judge-x'
    )
  end

  def row(model_result, judge_verdict) = { model_result:, judge_verdict: }

  describe 'bucket disagreement' do
    let(:rows) do
      [row(result(input_id: 1, model: 'm1', bucket: 'YES'), verdict(quality: 90)),
       row(result(input_id: 1, model: 'm2', bucket: 'NO'), verdict(quality: 88)),
       row(result(input_id: 2, model: 'm1', bucket: 'YES'), verdict(quality: 90)),
       row(result(input_id: 2, model: 'm2', bucket: 'YES'), verdict(quality: 85))]
    end
    let(:report) { described_class.new(rows:, run_id: 'r1', judge_model: 'judge-x', spec:).build }

    it 'flags inputs whose models disagree on bucket' do
      flagged = report.needs_review.select { |r| r[:input_id] == 1 }
      expect(flagged.size).to eq(2)
      expect(flagged.first[:reasons]).to include('buckets_disagree(NO,YES)')
    end

    it 'does not flag inputs where all models agree' do
      expect(report.needs_review.map { |r| r[:input_id] }).not_to include(2)
    end

    it 'renders a disagreement section in the markdown' do
      expect(report.to_markdown).to include('Bucket-disagreement cases')
      expect(report.to_markdown).to include('1 — label1')
    end
  end

  describe 'needs_human_review reasons' do
    let(:rows) do
      [row(result(input_id: 1, model: 'm1', bucket: 'YES'), verdict(quality: 60)), # borderline
       row(result(input_id: 2, model: 'm1', bucket: nil, status: 'parse_error'), verdict(quality: 0)),
       row(result(input_id: 3, model: 'm1', bucket: nil, status: 'llm_error'), nil)]
    end
    let(:report) { described_class.new(rows:, run_id: 'r1', judge_model: 'judge-x', spec:).build }

    it 'itemizes borderline, parse_failed and llm_error' do
      reasons = report.needs_review.to_h { |r| [r[:input_id], r[:reasons]] }
      expect(reasons[1]).to include('judge_borderline')
      expect(reasons[2]).to include('parse_failed')
      expect(reasons[3]).to include('llm_error')
    end
  end

  describe 'summary and pareto ordering' do
    let(:rows) do
      [row(result(input_id: 1, model: 'low', bucket: 'YES'), verdict(quality: 40)),
       row(result(input_id: 1, model: 'high', bucket: 'YES'), verdict(quality: 95)),
       row(result(input_id: 1, model: 'mid', bucket: 'YES'), verdict(quality: 70))]
    end
    let(:report) { described_class.new(rows:, run_id: 'r1', judge_model: 'judge-x', spec:).build }

    it 'orders summary by mean judge quality, best first' do
      expect(report.summary.map { |s| s[:model] }).to eq(%w[high mid low])
    end

    it 'reports per-model parse-OK and cost aggregates' do
      high = report.summary.find { |s| s[:model] == 'high' }
      expect(high[:parse_ok_pct]).to eq(100.0)
      expect(high[:total_cost]).to eq(0.01)
    end

    it 'lists the top picks in the markdown' do
      expect(report.to_markdown).to include('Top 3 by mean judge quality')
      expect(report.to_markdown).to include('`high`')
    end
  end

  describe 'CSV assembly' do
    let(:rows) { [row(result(input_id: 1, model: 'm1', bucket: 'YES'), verdict(quality: 90))] }
    let(:report) { described_class.new(rows:, run_id: 'r1', judge_model: 'm1', spec:).build }
    let(:table) { CSV.parse(report.to_csv, headers: true) }

    it 'includes base, per-dimension, extra and self_judge columns' do
      headers = table.headers
      expect(headers).to include('input_id', 'model', 'judge_quality_score',
                                 'judge_accuracy', 'judge_clarity', 'self_judge', 'summary')
    end

    it 'flags self_judge when candidate model == judge model' do
      expect(table.first['self_judge']).to eq('true')
    end

    it 'fills dimension and extra column values' do
      expect(table.first['judge_accuracy']).to eq('80')
      expect(table.first['summary']).to eq('a summary')
    end
  end
end
