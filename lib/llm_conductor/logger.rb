# frozen_string_literal: true

require 'logger'

module LlmConductor
  # Centralized logger for the LLM Conductor gem
  module Logger
    def self.instance
      @instance ||= ::Logger.new($stdout)
    end

    def self.debug(message)
      instance.debug(message)
    end

    def self.info(message)
      instance.info(message)
    end

    def self.warn(message)
      instance.warn(message)
    end

    def self.error(message)
      instance.error(message)
    end

    def self.fatal(message)
      instance.fatal(message)
    end

    # Allow configuration of logger level, output, etc.
    def self.configure
      yield(instance) if block_given?
    end
  end
end
