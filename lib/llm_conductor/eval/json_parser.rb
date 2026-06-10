# frozen_string_literal: true

require 'json'

module LlmConductor
  module Eval
    # Minimal, conservative JSON-from-LLM-text parser.
    #
    # Replaces the app-level LlmJsonCleaner the Rails prototype relied on. The
    # guiding principle (from docs/llm_eval_framework.md) is: NEVER "repair"
    # already-valid JSON — heavy cleaning corrupts numeric scores and the like.
    # We only strip markdown fences, drop any preamble before the first brace,
    # trim to the outermost balanced object/array, then parse once.
    module JsonParser
      module_function

      # Parse +text+ into a Hash or Array, or return nil on any failure.
      def parse(text)
        prepared = prepare_text(text)
        return nil if prepared.empty?

        obj = begin
          JSON.parse(prepared)
        rescue JSON::ParserError
          nil
        end
        obj.is_a?(Hash) || obj.is_a?(Array) ? obj : nil
      end

      # Strip ```json fences, drop preamble before the first [ or {, and trim
      # to the matching closing brace/bracket. Returns '' when there is no
      # JSON-looking content at all.
      def prepare_text(text)
        str = text.to_s.strip
                  .gsub(/\A```(?:json)?\s*/i, '')
                  .gsub(/```\s*\z/, '')
                  .strip
        start = str.index(/[\[{]/)
        return '' if start.nil?

        balance(str[start..])
      end

      # Given a string that starts with '{' or '[', return the substring up to
      # and including its matching close. String contents (and escapes) are
      # skipped so braces inside string literals don't throw off the depth.
      def balance(str)
        open = str[0]
        close = open == '{' ? '}' : ']'
        depth = 0
        in_string = false
        escape = false

        str.each_char.with_index do |char, index|
          if in_string
            if escape then escape = false
            elsif char == '\\' then escape = true
            elsif char == '"' then in_string = false
            end
            next
          end

          case char
          when '"' then in_string = true
          when open then depth += 1
          when close
            depth -= 1
            return str[0..index] if depth.zero?
          end
        end

        str
      end
    end
  end
end
