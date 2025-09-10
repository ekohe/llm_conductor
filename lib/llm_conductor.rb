# frozen_string_literal: true

require_relative 'llm_conductor/version'
require_relative 'llm_conductor/configuration'
require_relative 'llm_conductor/response'
require_relative 'llm_conductor/token_calculator'
require_relative 'llm_conductor/error_handler'
require_relative 'llm_conductor/retry_policy'
require_relative 'llm_conductor/prompt_manager'
require_relative 'llm_conductor/data_builder'
require_relative 'llm_conductor/prompts/base_prompt'
require_relative 'llm_conductor/clients/base_client'
require_relative 'llm_conductor/client_factory'

module LlmConductor
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ClientError < Error; end
  class PromptError < Error; end
  class TokenLimitError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def client(model:, type: nil, vendor: nil, **options)
      ClientFactory.build(
        model: model,
        type: type,
        vendor: vendor,
        configuration: configuration,
        **options
      )
    end

    def generate(model:, prompt: nil, data: nil, type: nil, **options)
      client_instance = client(model: model, type: type, **options)
      
      if prompt
        client_instance.generate_from_prompt(prompt: prompt)
      elsif data && type
        client_instance.generate(data: data)
      else
        raise ArgumentError, 'Either prompt or (data + type) must be provided'
      end
    end
  end
end
