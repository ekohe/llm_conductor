# frozen_string_literal: true

require 'llm_conductor/eval'

# Shared helpers for the eval specs: a sample Spec and a fake-Response builder
# so nothing hits the network.
module EvalSpecSupport
  # A minimal Spec over Hash inputs like { id:, name:, text: }.
  class SampleSpec < LlmConductor::Eval::Spec
    def prompt_type = :analyze_content
    def input_id(input) = input[:id]
    def input_label(input) = input[:name]
    def build_data(input) = { text: input[:text] }

    def output_summary(parsed)
      { score: parsed['score'], bucket: parsed['recommendation'] }
    end

    def judge_rubric_excerpt = 'Score the output 0-100 for accuracy and clarity.'

    def judge_dimensions
      [{ key: 'accuracy', description: 'is it factually accurate' },
       { key: 'clarity', description: 'is it clearly written' }]
    end

    def extra_columns(parsed) = { 'summary' => parsed['summary'] }
  end

  # Build a real LlmConductor::Response. Pass error: to simulate a failed call.
  def build_response(output:, model: 'test-model', input_tokens: 10, output_tokens: 20, error: nil)
    LlmConductor::Response.new(
      output:, model:, input_tokens:, output_tokens:,
      metadata: error ? { error: } : {}
    )
  end

  # Candidate output JSON string for a given score/bucket.
  def candidate_json(score: 80, recommendation: 'YES', summary: 'looks good')
    JSON.generate('score' => score, 'recommendation' => recommendation, 'summary' => summary)
  end

  # Judge verdict JSON string.
  def judge_json(quality_score: 85, accuracy: 80, clarity: 90)
    JSON.generate(
      'quality_score' => quality_score,
      'dimensions' => { 'accuracy' => accuracy, 'clarity' => clarity },
      'issues' => ['minor nit'],
      'verdict_one_line' => 'solid'
    )
  end
end

RSpec.configure do |config|
  config.include EvalSpecSupport
end
