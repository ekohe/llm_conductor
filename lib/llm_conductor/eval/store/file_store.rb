# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative 'base'

module LlmConductor
  module Eval
    module Store
      # Resumable on-disk store. Reproduces the Rails prototype's layout:
      #
      #   <base_dir>/<run_id>/manifest.json
      #   <base_dir>/<run_id>/<input_id>/_input.json
      #   <base_dir>/<run_id>/<input_id>/<model_slug>.raw.txt
      #   <base_dir>/<run_id>/<input_id>/<model_slug>.json
      #
      # The manifest is rewritten after every (input, model) pair, so a run is
      # reportable / re-judgeable mid-flight (see Runner.report_only/judge_only).
      class FileStore < Base
        attr_reader :base_dir

        def initialize(base_dir)
          super()
          @base_dir = base_dir.to_s
        end

        def write_raw(run_id, input_id, model_slug, text)
          write_file(output_path(run_id, input_id, "#{model_slug}.raw.txt"), text.to_s)
        end

        def read_raw(run_id, input_id, model_slug)
          read_file(output_path(run_id, input_id, "#{model_slug}.raw.txt"))
        end

        def write_parsed(run_id, input_id, model_slug, hash)
          write_file(output_path(run_id, input_id, "#{model_slug}.json"), JSON.pretty_generate(hash))
        end

        def read_parsed(run_id, input_id, model_slug)
          read_json(output_path(run_id, input_id, "#{model_slug}.json"))
        end

        def write_input_data(run_id, input_id, hash)
          write_file(output_path(run_id, input_id, '_input.json'), JSON.pretty_generate(hash))
        end

        def read_input_data(run_id, input_id)
          read_json(output_path(run_id, input_id, '_input.json'))
        end

        def write_manifest(run_id, manifest_hash)
          write_file(manifest_path(run_id), JSON.pretty_generate(manifest_hash))
        end

        def read_manifest(run_id)
          read_json(manifest_path(run_id))
        end

        def completed?(run_id, input_id, model_slug)
          File.exist?(output_path(run_id, input_id, "#{model_slug}.json")) ||
            File.exist?(output_path(run_id, input_id, "#{model_slug}.raw.txt"))
        end

        private

        def output_path(run_id, input_id, name)
          File.join(@base_dir, run_id.to_s, input_id.to_s, name)
        end

        def manifest_path(run_id)
          File.join(@base_dir, run_id.to_s, 'manifest.json')
        end

        def write_file(path, content)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, content)
          path
        end

        def read_file(path)
          File.exist?(path) ? File.read(path) : nil
        end

        def read_json(path)
          return nil unless File.exist?(path)

          JSON.parse(File.read(path))
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
