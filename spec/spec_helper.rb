# frozen_string_literal: true

require 'active_support'
require 'active_support/time'
require 'active_support/time_with_zone'
require 'groq'
require 'llm_conductor'

# Configure timezone for tests
Time.zone = 'UTC'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset configuration before each test to ensure clean state
  config.before do
    # Reset configuration to defaults
    LlmConductor.instance_variable_set(:@configuration, nil)
  end

  # Set up common test configuration
  config.before(:each, :with_test_config) do
    LlmConductor.configure do |llm_config|
      llm_config.openai_api_key = 'test_openai_key'
      llm_config.openrouter_api_key = 'test_openrouter_key'
      llm_config.ollama_address = 'http://test.ollama:11434'
      llm_config.default_model = 'test-model'
      llm_config.default_vendor = :openai
    end
  end
end
