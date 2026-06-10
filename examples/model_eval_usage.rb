# frozen_string_literal: true

# Model Evaluation harness example.
#
# Runs the same prompt across several (model, vendor) pairs over a handful of
# inputs and compares them on cost, latency, tokens, and LLM-judged quality.
#
# Run with:  ruby examples/model_eval_usage.rb
#
# Requires credentials for whichever vendors you list in CANDIDATES (and Groq
# for the default judge). Configure them via ENV (OPENAI_API_KEY, GEMINI_API_KEY,
# GROQ_API_KEY, OLLAMA_ADDRESS, ...) or LlmConductor.configure.

require 'llm_conductor/eval'

# 1. A Spec describes the ONE feature being evaluated. It is the only
#    feature-specific code; the engine itself is generic.
class SentimentSpec < LlmConductor::Eval::Spec
  # We build a full prompt string ourselves, so prompt_type is nil and the
  # engine passes build_data as `prompt:` (instead of `type:` + `data:`).
  def prompt_type = nil

  def input_id(review)    = review[:id]
  def input_label(review) = review[:product]

  def build_data(review)
    <<~PROMPT
      Classify the sentiment of this product review. Respond with ONLY a JSON
      object: {"sentiment": "positive|neutral|negative", "confidence": 0-100}

      Review: #{review[:text]}
    PROMPT
  end

  # score + bucket drive the CSV and bucket-disagreement detection. The bucket
  # here is the sentiment label — if models disagree on it, the row is flagged.
  def output_summary(parsed)
    { score: parsed['confidence'], bucket: parsed['sentiment'] }
  end

  def judge_rubric_excerpt
    'A correct classification matches the review\'s actual sentiment and gives ' \
      'a calibrated confidence (high only when the text is unambiguous).'
  end

  def judge_dimensions
    [{ key: 'correctness', description: 'is the sentiment label correct' },
     { key: 'calibration', description: 'is the confidence well-calibrated' }]
  end
end

# 2. Inputs are ANY enumerable of opaque objects — selecting them is YOUR job.
reviews = [
  { id: 1, product: 'Widget',  text: 'Absolutely love it, works perfectly!' },
  { id: 2, product: 'Gadget',  text: 'It broke after two days. Very disappointed.' },
  { id: 3, product: 'Gizmo',   text: 'It is fine. Does what it says, nothing special.' }
]

# 3. Candidate (model, vendor) pairs are caller-owned — there is no baked-in
#    default list (which models you have pulled / hold keys for is your concern).
CANDIDATES = [
  { model: 'gpt-4o-mini',      vendor: :openai },
  { model: 'gemini-2.5-flash', vendor: :gemini }
].freeze

report = LlmConductor::Eval.run(
  spec: SentimentSpec.new,
  inputs: reviews,
  models: CANDIDATES,
  # Judge defaults to llama-3.3-70b-versatile on Groq (outside the candidate
  # families → no self-judge bias). Override here if you have other quota.
  judge: { model: 'llama-3.3-70b-versatile', vendor: :groq },
  # InMemory store is the default; swap in FileStore to persist + enable
  # report_only / judge_only re-runs:
  store: LlmConductor::Eval::Store::FileStore.new('tmp/llm_eval')
)

puts report.to_markdown
puts "\n--- Rows needing human review ---"
report.needs_review.each do |row|
  puts "input=#{row[:input_id]} model=#{row[:model]} reasons=#{row[:reasons].join(', ')}"
end

# Persist the CSV yourself — the engine returns data, it doesn't impose a layout.
File.write('tmp/llm_eval_results.csv', report.to_csv)
puts "\nWrote tmp/llm_eval_results.csv"
