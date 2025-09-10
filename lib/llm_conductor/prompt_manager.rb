# frozen_string_literal: true

module LlmConductor
  class PromptManager
    @prompts = {}

    class << self
      def register(name, prompt_class_or_template)
        @prompts[name.to_sym] = prompt_class_or_template
      end

      def build_prompt(name, data)
        prompt_definition = @prompts[name.to_sym]
        
        unless prompt_definition
          raise PromptError, "Prompt '#{name}' not registered"
        end

        case prompt_definition
        when Class
          if prompt_definition < Prompts::BasePrompt
            prompt_definition.new(data).render
          else
            raise PromptError, "Prompt class must inherit from Prompts::BasePrompt"
          end
        when String
          render_template(prompt_definition, data)
        when Proc
          prompt_definition.call(data)
        else
          raise PromptError, "Invalid prompt definition for '#{name}'"
        end
      end

      def registered_prompts
        @prompts.keys
      end

      def unregister(name)
        @prompts.delete(name.to_sym)
      end

      def clear_all
        @prompts.clear
      end

      private

      def render_template(template, data)
        # Simple template rendering using ERB
        require 'erb'
        
        # Convert data hash to allow method-style access
        binding_object = OpenStruct.new(data) if data.is_a?(Hash)
        binding_object ||= data
        
        ERB.new(template).result(binding_object.instance_eval { binding })
      end
    end
  end
end
