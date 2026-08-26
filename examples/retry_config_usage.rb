#!/usr/bin/env ruby
# frozen_string_literal: true

# Retry configuration (config.max_retries / config.retry_delay).
#
# Transient provider failures — a 429 from a saturated quota pool, a 503 from an
# overloaded region, a dropped connection — are retried with exponential backoff
# seeded from retry_delay, up to max_retries *total* attempts (so the default of 3
# means one call plus at most two retries).
#
# Statuses that will not change on a second identical request (400, 401, 403, 404,
# 422) are never retried; they surface on the first attempt.
#
#   GEMINI_API_KEY=... ruby examples/retry_config_usage.rb
#
# The last section needs no API key: it prints the backoff curve so you can see
# what a given retry_delay actually costs before you set it in production.

require_relative '../lib/llm_conductor'
require 'logger'

MODEL = ENV['MODEL'] || 'gemini-2.5-flash'
PROMPT = 'Name the capital of France. Answer with one word.'

LlmConductor.configure do |config|
  config.gemini(api_key: ENV['GEMINI_API_KEY']) if ENV['GEMINI_API_KEY']

  # Total attempts, including the first. Set to 1 to disable retrying.
  config.max_retries = 3

  # Seconds before the first retry; each further retry doubles it.
  config.retry_delay = 1.0

  # With a logger configured, every retry emits one warn line naming the attempt,
  # the status and the delay. The API key is never part of it.
  config.logger = Logger.new($stdout)
end

if ENV['GEMINI_API_KEY']
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  response = LlmConductor.generate(model: MODEL, prompt: PROMPT, vendor: :gemini)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

  if response.success?
    puts "OK in #{elapsed.round(2)}s — #{response.output.to_s.strip}"
  else
    # Reached only after the whole attempt budget is spent. Retries ride out short
    # spikes; they do not survive a sustained quota outage.
    puts "FAILED after #{elapsed.round(2)}s — #{response.metadata[:error]}"
    puts "  error class: #{response.metadata[:error_class]}"
  end
else
  puts 'GEMINI_API_KEY not set — skipping the live call.'
end

puts
puts 'Backoff curve (before jitter, which only ever adds):'

retryable = LlmConductor::Clients::Concerns::Retryable
[0.25, 1.0, 5.0].each do |retry_delay|
  delays = (1...LlmConductor.configuration.max_retries).map do |attempt|
    [retry_delay * (2**(attempt - 1)), retryable::MAX_BACKOFF_SECONDS].min
  end
  total = delays.sum
  puts format(
    '  retry_delay=%<seed>-5s waits %<waits>-22s worst case %<total>.2fs of waiting',
    seed: retry_delay, waits: delays.map { |d| "#{d}s" }.join(', '), total:
  )
end

puts
puts 'Retried:     429, 500, 502, 503, 504, 408, connection/read timeouts'
puts 'Not retried: 400, 401, 403, 404, 422, TLS errors — see docs/retries.md'
