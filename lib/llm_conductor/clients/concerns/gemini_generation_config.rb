# frozen_string_literal: true

module LlmConductor
  module Clients
    module Concerns
      # Builds Gemini's generationConfig payload from the generic snake_case +params+
      # hash accepted by every client.
      #
      # The Gemini REST API expects camelCase keys inside generationConfig, and nests
      # the Gemini 3.x thinking controls one level deeper, under
      # generationConfig.thinkingConfig. Callers keep passing snake_case Ruby keys —
      # the translation lives here.
      #
      # Keys without a mapping are skipped and reported through the configured logger
      # instead of disappearing silently. Skipping rather than raising keeps existing
      # callers that pass provider-agnostic params working unchanged.
      module GeminiGenerationConfig
        # Gemini REST API uses camelCase keys in generationConfig.
        PARAM_KEY_MAP = {
          temperature: :temperature,
          top_p: :topP,
          top_k: :topK,
          max_tokens: :maxOutputTokens,
          max_output_tokens: :maxOutputTokens,
          candidate_count: :candidateCount,
          stop_sequences: :stopSequences
        }.freeze

        # Keys nested under generationConfig.thinkingConfig (Gemini 3.x thinking
        # controls). Accepted flat in params or inside a thinking_config hash.
        THINKING_KEY_MAP = {
          thinking_level: :thinkingLevel,
          thinking_budget: :thinkingBudget,
          include_thoughts: :includeThoughts
        }.freeze

        # Param keys carrying a nested thinkingConfig hash.
        THINKING_CONFIG_KEYS = %i[thinking_config thinkingConfig].freeze

        private

        # Build Gemini generationConfig from the params hash.
        #
        # Thinking controls may be passed flat (thinking_level: 'minimal') or nested
        # (thinking_config: { thinking_level: 'minimal' }); either way they end up in
        # generationConfig.thinkingConfig, and both forms together are merged.
        #
        # @return [Hash, nil] generationConfig hash, or nil when nothing maps
        def build_generation_config
          return unless params.is_a?(Hash) && params.any?

          gen_cfg = {}
          thinking_cfg = {}
          params.each { |key, value| assign_generation_param(key, value, gen_cfg, thinking_cfg) }
          gen_cfg[:thinkingConfig] = thinking_cfg if thinking_cfg.any?
          gen_cfg.any? ? gen_cfg : nil
        end

        # Route a single param into generationConfig or its nested thinkingConfig.
        def assign_generation_param(key, value, gen_cfg, thinking_cfg)
          if THINKING_CONFIG_KEYS.include?(key.to_sym)
            thinking_cfg.merge!(normalize_thinking_config(value))
          elsif (thinking_key = thinking_config_key_for(key))
            thinking_cfg[thinking_key] = value
          elsif (mapped = PARAM_KEY_MAP[key.to_sym])
            gen_cfg[mapped] = value
          else
            warn_unmapped_param(key)
          end
        end

        # Normalize a nested thinking_config hash to the API's camelCase keys.
        # @param value [Hash] thinking config as given by the caller
        # @return [Hash] camelCase thinkingConfig fragment
        def normalize_thinking_config(value)
          unless value.is_a?(Hash)
            warn_unmapped_param(:thinking_config, reason: "expected a Hash, got #{value.class}")
            return {}
          end

          value.each_with_object({}) do |(key, val), cfg|
            mapped = thinking_config_key_for(key)
            if mapped
              cfg[mapped] = val
            else
              warn_unmapped_param(key, scope: 'thinkingConfig')
            end
          end
        end

        # Resolve a thinkingConfig key, accepting snake_case or the camelCase API name.
        # @return [Symbol, nil] camelCase API key, or nil when unknown
        def thinking_config_key_for(key)
          sym_key = key.to_sym
          THINKING_KEY_MAP[sym_key] || (sym_key if THINKING_KEY_MAP.value?(sym_key))
        end

        # Report a param the client cannot map. Non-fatal by design: unmapped keys are
        # skipped, but never without a trace — configure LlmConductor.configuration.logger
        # to surface them.
        def warn_unmapped_param(key, scope: 'generationConfig', reason: 'no Gemini API mapping')
          configuration.logger&.warn(
            "[LlmConductor::Clients::GeminiClient] Skipping #{scope} param #{key.inspect}: #{reason}. " \
            'See docs/custom-parameters.md for the supported keys.'
          )
        end
      end
    end
  end
end
