# frozen_string_literal: true

require 'logger'

module LlmConductor
  # Centralized logger for the LLM Conductor gem
  module Logger
    def self.instance
      if @instance.nil? || @instance.level != log_level_constant
        @instance = begin
          logger = ::Logger.new($stdout)
          logger.level = log_level_constant
          logger
        end
      end
      @instance
    end

    def self.log_level_constant
      case LlmConductor.configuration.log_level
      when :debug then ::Logger::DEBUG
      when :info then ::Logger::INFO
      when :warn then ::Logger::WARN
      when :error then ::Logger::ERROR
      when :fatal then ::Logger::FATAL
      else ::Logger::WARN
      end
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
