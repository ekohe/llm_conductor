#!/usr/bin/env ruby
# frozen_string_literal: true

# Connectivity test for all Gemini auth methods.
# Omit SCENARIO to run all scenarios that have the required env vars set.
#
#   Scenario A — Generative Language API (api_key)
#     SCENARIO=api_key GEMINI_API_KEY=... ruby examples/gemini_usage.rb
#
#   Scenario B — Vertex AI with account-bound API key
#     SCENARIO=vertex_api_key GEMINI_API_KEY=... GOOGLE_VERTEX_PROJECT_ID=... ruby examples/gemini_usage.rb
#
#   Scenario C — Vertex AI via Application Default Credentials
#     SCENARIO=adc \
#     GOOGLE_VERTEX_PROJECT_ID=... \
#     GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json \
#     ruby examples/gemini_usage.rb
#
#   Scenario C — Vertex AI via credentials file contents
#     SCENARIO=file_contents \
#     GOOGLE_VERTEX_PROJECT_ID=... \
#     GOOGLE_CREDENTIALS_FILE_CONTENTS=$(cat /path/to/sa.json) \
#     ruby examples/gemini_usage.rb

require_relative '../lib/llm_conductor'

MODEL  = 'gemini-2.5-flash'
PROMPT = 'Say hello.'

SCENARIOS = {
  'api_key' => -> { ENV['GEMINI_API_KEY'] && !ENV['GOOGLE_VERTEX_PROJECT_ID'] },
  'vertex_api_key' => -> { ENV['GEMINI_API_KEY'] && ENV['GOOGLE_VERTEX_PROJECT_ID'] },
  'adc' => -> { ENV['GOOGLE_VERTEX_PROJECT_ID'] && ENV['GOOGLE_APPLICATION_CREDENTIALS'] },
  'file_contents' => -> { ENV['GOOGLE_VERTEX_PROJECT_ID'] && ENV['GOOGLE_CREDENTIALS_FILE_CONTENTS'] }
}.freeze

def run_scenario(name)
  case name
  when 'api_key'
    LlmConductor.configure { |c| c.gemini(api_key: ENV.fetch('GEMINI_API_KEY')) }
    label = 'api_key'

  when 'vertex_api_key'
    LlmConductor.configure do |c|
      c.gemini(api_key: ENV.fetch('GEMINI_API_KEY'),
               project_id: ENV.fetch('GOOGLE_VERTEX_PROJECT_ID'),
               region: ENV['GOOGLE_VERTEX_REGION'])
    end
    label = 'vertex_ai/api_key'

  when 'adc'
    LlmConductor.configure do |c|
      c.gemini(project_id: ENV.fetch('GOOGLE_VERTEX_PROJECT_ID'),
               region: ENV['GOOGLE_VERTEX_REGION'])
    end
    label = 'vertex_ai/adc'

  when 'file_contents'
    LlmConductor.configure do |c|
      c.gemini(project_id: ENV.fetch('GOOGLE_VERTEX_PROJECT_ID'),
               region: ENV['GOOGLE_VERTEX_REGION'],
               file_contents: ENV.fetch('GOOGLE_CREDENTIALS_FILE_CONTENTS'))
    end
    label = 'vertex_ai/file_contents'
  end

  response = LlmConductor.generate(model: MODEL, prompt: PROMPT)
  raise 'Empty response' if response.output.nil? || response.output.strip.empty?

  puts "[#{label}] OK — #{response.output.strip}"
rescue StandardError => e
  puts "[#{label}] FAILED — #{e.message}"
  false
end

scenario = ENV['SCENARIO']

if scenario
  abort "Unknown SCENARIO=#{scenario}. Use: api_key | vertex_api_key | adc | file_contents" unless SCENARIOS.key?(scenario)
  run_scenario(scenario)
else
  ran = 0
  SCENARIOS.each do |name, available|
    next unless available.call

    run_scenario(name)
    ran += 1
  end
  puts '(no scenarios ran — set the required env vars)' if ran.zero?
end
