# frozen_string_literal: true

require 'json'
require_relative 'base'

module LlmConductor
  module Eval
    module Store
      # Default store: everything lives in process memory, nothing hits disk.
      # Ideal for tests and ephemeral runs. Manifests are round-tripped through
      # JSON on write so reads return string-keyed hashes, matching FileStore.
      class InMemory < Base
        def initialize
          super
          @raw = {}
          @parsed = {}
          @inputs = {}
          @manifests = {}
        end

        def write_raw(run_id, input_id, model_slug, text)
          key = output_key(run_id, input_id, model_slug)
          @raw[key] = text.to_s
          "memory://#{key}.raw"
        end

        def read_raw(run_id, input_id, model_slug)
          @raw[output_key(run_id, input_id, model_slug)]
        end

        def write_parsed(run_id, input_id, model_slug, hash)
          key = output_key(run_id, input_id, model_slug)
          @parsed[key] = hash
          "memory://#{key}.json"
        end

        def read_parsed(run_id, input_id, model_slug)
          @parsed[output_key(run_id, input_id, model_slug)]
        end

        def write_input_data(run_id, input_id, hash)
          # Round-trip through JSON so reads return string-keyed hashes, matching
          # FileStore — keeps judge_only/report_only behavior identical across stores.
          @inputs[input_key(run_id, input_id)] = JSON.parse(JSON.generate(hash))
        end

        def read_input_data(run_id, input_id)
          @inputs[input_key(run_id, input_id)]
        end

        def write_manifest(run_id, manifest_hash)
          @manifests[run_id.to_s] = JSON.parse(JSON.generate(manifest_hash))
        end

        def read_manifest(run_id)
          @manifests[run_id.to_s]
        end

        def completed?(run_id, input_id, model_slug)
          key = output_key(run_id, input_id, model_slug)
          @parsed.key?(key) || @raw.key?(key)
        end

        private

        def output_key(run_id, input_id, model_slug)
          "#{run_id}/#{input_id}/#{model_slug}"
        end

        def input_key(run_id, input_id)
          "#{run_id}/#{input_id}"
        end
      end
    end
  end
end
