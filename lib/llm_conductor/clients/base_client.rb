# frozen_string_literal: true

module LlmConductor
  module Clients
    class BaseClient
      attr_reader :model, :type, :configuration, :options

      def initialize(model:, type: nil, configuration: nil, **options)
        @model = model.to_s
        @type = type&.to_sym
        @configuration = configuration || LlmConductor.configuration
        @options = options
        @error_handler = ErrorHandler.new(@configuration)
        @token_calculator = TokenCalculator.new
      end

      def generate(data:)
        prompt = build_prompt(data)
        generate_from_prompt(prompt: prompt)
      end

      def generate_from_prompt(prompt:)
        validate_prompt(prompt)
        
        @error_handler.with_retry do
          input_tokens = @token_calculator.calculate(prompt)
          output = generate_content(prompt)
          output_tokens = @token_calculator.calculate(output)

          Response.new(
            input: prompt,
            output: output,
            input_tokens: input_tokens,
            output_tokens: output_tokens,
            model: model,
            vendor: vendor_name
          )
        end
      end

      protected

      def build_prompt(data)
        return data if data.is_a?(String)
        
        if @type
          PromptManager.build_prompt(@type, data)
        else
          raise PromptError, 'No prompt type specified and data is not a string'
        end
      end

      def validate_prompt(prompt)
        return unless prompt.nil? || prompt.strip.empty?
        
        raise PromptError, 'Prompt cannot be nil or empty'
      end

      def generate_content(prompt)
        raise NotImplementedError, 'Subclasses must implement generate_content'
      end

      def vendor_name
        self.class.name.split('::').last.gsub('Client', '').downcase.to_sym
      end

      def provider_config
        @provider_config ||= @configuration.provider_config(vendor_name)
      end

      private

      attr_reader :error_handler, :token_calculator
    end
  end
end
