#!/usr/bin/env ruby
# frozen_string_literal: true

# Gemini thinking configuration (generationConfig.thinkingConfig).
#
# Gemini 3.x models think before answering. Trimming that budget is the biggest
# latency lever on the fast models, so llm_conductor exposes it through params:
#
#   params: { thinking_level: 'minimal' }                       # flat convenience key
#   params: { thinking_config: { thinking_level: 'minimal' } }  # nested, mirrors the API
#
# Both reach the API as generationConfig.thinkingConfig.thinkingLevel.
#
#   GEMINI_API_KEY=... ruby examples/gemini_thinking_usage.rb
#   GEMINI_API_KEY=... MODEL=gemini-3.5-flash-lite ruby examples/gemini_thinking_usage.rb

require_relative '../lib/llm_conductor'
require 'logger'

MODEL = ENV['MODEL'] || 'gemini-2.5-flash'
PROMPT = 'Name the capital of France. Answer with one word.'

LlmConductor.configure do |config|
  config.gemini(api_key: ENV.fetch('GEMINI_API_KEY'))
  # With a logger configured, any param the client cannot map is reported
  # instead of being dropped silently.
  config.logger = Logger.new($stdout)
end

CASES = {
  'no thinking config' => {},
  'flat thinking_level' => { thinking_level: 'minimal' },
  'nested thinking_config' => { thinking_config: { thinking_level: 'minimal' } },
  'thinking_budget: 0' => { thinking_config: { thinking_budget: 0 } },
  'unmapped param (expect a warning)' => { reasoning_effort: 'high' }
}.freeze

CASES.each do |label, params|
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  response = LlmConductor.generate(model: MODEL, prompt: PROMPT, vendor: :gemini, params:)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

  if response.success?
    puts "[#{label}] #{elapsed.round(2)}s — #{response.output.to_s.strip}"
  else
    puts "[#{label}] FAILED — #{response.metadata[:error]}"
  end
end
