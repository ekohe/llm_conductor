# frozen_string_literal: true

require 'json'
require_relative 'verdict'
require_relative 'json_parser'
require_relative 'model_runner'

module LlmConductor
  module Eval
    # LLM-as-judge for one candidate (input, model) output.
    #
    # Sends the judge model the original input data, the spec's rubric excerpt,
    # and the candidate's parsed output (or raw text on parse failure), and
    # expects strict JSON back with a quality_score + per-dimension scores.
    #
    # Judge defaults to Groq's llama-3.3-70b-versatile: it sits OUTSIDE the
    # Gemini/OpenAI/Ollama families that dominate most candidate lists (avoiding
    # self-judge bias — Gemini grades its own output ~10pts high) and Groq's
    # free tier offers far more throughput than Gemini Pro's ~2 RPM. Override
    # via the +judge:+ config. It needs Groq credentials configured; rows where
    # the judged model == the judge model are flagged +self_judge+ in the report.
    class Judge
      DEFAULT_MODEL = 'llama-3.3-70b-versatile'
      DEFAULT_VENDOR = :groq

      def self.borderline?(score)
        Verdict.borderline?(score)
      end

      def initialize(spec:, store:, run_id:, logger:, judge_model: DEFAULT_MODEL,
                     judge_vendor: DEFAULT_VENDOR, rate_limit_retries: 3,
                     rate_limit_backoff_seconds: 20)
        @spec = spec
        @store = store
        @run_id = run_id
        @logger = logger
        @judge_model = judge_model
        @judge_vendor = judge_vendor.to_sym
        @rate_limit_retries = rate_limit_retries
        @rate_limit_backoff_seconds = rate_limit_backoff_seconds
      end

      # +model_result+ is an Eval::Result. +input_data+ is the spec's data Hash
      # for the input being judged.
      def judge(model_result:, input_data:)
        prompt = build_prompt(model_result:, input_data:)
        response, latency_ms = call_with_rate_limit_retry(prompt)

        unless response&.success?
          error = response&.metadata&.dig(:error) || 'judge LLM call failed'
          return failure_verdict(latency_ms:, response:, error:)
        end

        parsed = JsonParser.parse(response.output)
        if parsed.nil?
          return failure_verdict(latency_ms:, response:,
                                 error: "judge output not valid JSON: #{response.output.to_s[0, 200]}")
        end

        build_verdict(parsed:, latency_ms:, response:)
      rescue StandardError => e
        @logger.error("[Eval::Judge] #{@judge_model}: #{e.class}: #{e.message}")
        Verdict.new(judge_model: @judge_model, judge_error: "#{e.class}: #{e.message}")
      end

      private

      def build_verdict(parsed:, latency_ms:, response:)
        Verdict.new(
          quality_score: clamp_score(parsed['quality_score']),
          dimensions: extract_dimensions(parsed['dimensions']),
          issues: Array(parsed['issues']).map(&:to_s),
          verdict_one_line: parsed['verdict_one_line'].to_s,
          judge_model: @judge_model,
          judge_latency_ms: latency_ms,
          judge_input_tokens: response.input_tokens,
          judge_output_tokens: response.output_tokens,
          judge_estimated_cost_usd: response.estimated_cost
        )
      end

      def call_with_rate_limit_retry(prompt)
        attempt = 0
        started_at = Time.now.utc
        loop do
          response = LlmConductor.generate(model: @judge_model, prompt:, vendor: @judge_vendor)
          if !response&.success? && rate_limited?(response) && attempt < @rate_limit_retries
            wait = @rate_limit_backoff_seconds * (2**attempt)
            @logger.warn("[Eval::Judge] 429 from #{@judge_model}; sleeping #{wait}s then retrying " \
                         "(attempt #{attempt + 1}/#{@rate_limit_retries})")
            sleep(wait)
            attempt += 1
            next
          end
          return [response, ((Time.now.utc - started_at) * 1000).round]
        end
      end

      def rate_limited?(response)
        error = response&.metadata&.dig(:error).to_s
        error.include?('429') || error.match?(/rate.limit/i)
      end

      def build_prompt(model_result:, input_data:)
        <<~PROMPT
          You are an impartial judge evaluating how well a candidate LLM performed a
          task against its rubric. Score the candidate's output on a 0-100 quality
          scale. Be strict but fair: a perfect rubric-adherent response grounded in
          the provided evidence is 90-100; obvious hallucinations or rubric violations
          should drop the score significantly.

          <rubric_excerpt>
          #{@spec.judge_rubric_excerpt}
          </rubric_excerpt>

          <original_input_data>
          #{JSON.pretty_generate(input_data)}
          </original_input_data>

          <candidate_output>
          #{candidate_block(model_result)}
          </candidate_output>

          <judging_dimensions>
          #{judging_dimensions_block}
          </judging_dimensions>

          Return ONE JSON object with no markdown fences and no commentary:

          {
            "quality_score": 0-100,
            "dimensions": {
          #{dimensions_json_template}
            },
            "issues": ["concrete one-line problem", "..."],
            "verdict_one_line": "one-line summary of overall judgment"
          }
        PROMPT
      end

      def candidate_block(model_result)
        slug = ModelRunner.slug(model_result.model)
        parsed = @store.read_parsed(@run_id, model_result.input_id, slug)
        return parsed.is_a?(String) ? parsed : JSON.pretty_generate(parsed) if parsed

        raw = @store.read_raw(@run_id, model_result.input_id, slug)
        if raw && !raw.empty?
          "PARSE FAILED. RAW OUTPUT:\n#{raw}"
        else
          "CANDIDATE PRODUCED NO USABLE OUTPUT. status=#{model_result.status} error=#{model_result.error}"
        end
      end

      def judging_dimensions_block
        @spec.judge_dimensions.map { |d| "  - #{d[:key]} (0-100): #{d[:description]}" }.join("\n")
      end

      def dimensions_json_template
        @spec.judge_dimensions.map { |d| "    \"#{d[:key]}\": 0-100" }.join(",\n")
      end

      def extract_dimensions(raw)
        return {} unless raw.is_a?(Hash)

        @spec.judge_dimensions.each_with_object({}) do |d, acc|
          acc[d[:key]] = clamp_score(raw[d[:key]] || raw[d[:key].to_s])
        end
      end

      def clamp_score(raw)
        return nil if raw.nil?

        Integer(raw).clamp(0, 100)
      rescue ArgumentError, TypeError
        nil
      end

      def failure_verdict(latency_ms:, response:, error:)
        Verdict.new(
          judge_model: @judge_model, judge_latency_ms: latency_ms,
          judge_input_tokens: response&.input_tokens, judge_output_tokens: response&.output_tokens,
          judge_estimated_cost_usd: response&.estimated_cost, judge_error: error,
          quality_score: 0, dimensions: {}, issues: [], verdict_one_line: ''
        )
      end
    end
  end
end
