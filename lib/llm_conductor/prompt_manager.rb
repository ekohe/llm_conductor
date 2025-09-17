# frozen_string_literal: true

module LlmConductor
  # Manages registration and creation of prompt classes
  class PromptManager
    class PromptNotFoundError < StandardError; end
    class InvalidPromptClassError < StandardError; end

    @registry = {}

    class << self
      attr_reader :registry

      # Register a prompt class with a given type
      def register(type, prompt_class)
        validate_prompt_class!(prompt_class)

        @registry[type.to_sym] = prompt_class
      end

      # Unregister a prompt type (useful for testing)
      def unregister(type)
        @registry.delete(type.to_sym)
      end

      # Get a registered prompt class
      def get(type)
        @registry[type.to_sym] || raise(PromptNotFoundError, "Prompt type :#{type} not found")
      end

      # Check if a prompt type is registered
      def registered?(type)
        @registry.key?(type.to_sym)
      end

      # List all registered prompt types
      def types
        @registry.keys
      end

      # Clear all registrations (useful for testing)
      def clear!
        @registry.clear
      end

      # Create a prompt instance
      def create(type, data = {})
        prompt_class = get(type)
        prompt_class.new(data)
      end

      # Create and render a prompt in one step
      def render(type, data = {})
        create(type, data).render
      end

      private

      def validate_prompt_class!(prompt_class)
        raise InvalidPromptClassError, 'Prompt must be a class' unless prompt_class.is_a?(Class)

        unless prompt_class < Prompts::BasePrompt
          raise InvalidPromptClassError, 'Prompt class must inherit from BasePrompt'
        end

        return if prompt_class.instance_methods(false).include?(:render)

        raise InvalidPromptClassError, 'Prompt class must implement #render method'
      end
    end
  end
end
