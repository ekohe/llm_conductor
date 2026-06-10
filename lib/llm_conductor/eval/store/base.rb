# frozen_string_literal: true

module LlmConductor
  module Eval
    module Store
      # Pluggable persistence interface for an eval run. Replaces the prototype's
      # hard-coded Rails.root.join('tmp', ...) + File.read/write calls.
      #
      # Two implementations ship with the gem: InMemory (default; nothing hits
      # disk) and FileStore (resumable, reproduces the prototype's tmp/<run_id>/
      # layout). Implement this interface to persist anywhere else.
      #
      # Write methods return an opaque "ref" (a filesystem path for FileStore, a
      # key for InMemory) recorded on the Result for the report's path columns.
      class Base
        def write_raw(_run_id, _input_id, _model_slug, _text)
          raise NotImplementedError
        end

        def read_raw(_run_id, _input_id, _model_slug)
          raise NotImplementedError
        end

        def write_parsed(_run_id, _input_id, _model_slug, _hash)
          raise NotImplementedError
        end

        # Returns the parsed Hash/Array (not the ref), or nil if absent.
        def read_parsed(_run_id, _input_id, _model_slug)
          raise NotImplementedError
        end

        def write_input_data(_run_id, _input_id, _hash)
          raise NotImplementedError
        end

        # Enables self-contained re-judge / report without the original inputs.
        def read_input_data(_run_id, _input_id)
          raise NotImplementedError
        end

        def write_manifest(_run_id, _manifest_hash)
          raise NotImplementedError
        end

        def read_manifest(_run_id)
          raise NotImplementedError
        end

        # True when this (input, model) pair already has stored output — lets a
        # future restart skip already-completed pairs.
        def completed?(_run_id, _input_id, _model_slug)
          raise NotImplementedError
        end
      end
    end
  end
end
