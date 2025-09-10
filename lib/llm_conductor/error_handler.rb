# frozen_string_literal: true

module LlmConductor
  class ErrorHandler
    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
    end

    def with_retry(&block)
      attempt = 1
      max_attempts = configuration.max_retries + 1

      begin
        block.call
      rescue *retryable_errors => e
        if attempt < max_attempts
          delay = calculate_delay(attempt)
          Rails.logger.warn "LLM request failed (attempt #{attempt}/#{max_attempts}): #{e.message}. Retrying in #{delay}s..." if defined?(Rails)
          
          sleep(delay)
          attempt += 1
          retry
        else
          raise ClientError, "Request failed after #{max_attempts} attempts: #{e.message}"
        end
      rescue *non_retryable_errors => e
        raise ClientError, "Request failed with non-retryable error: #{e.message}"
      end
    end

    private

    def retryable_errors
      [
        Net::TimeoutError,
        Net::ReadTimeout,
        Net::OpenTimeout,
        Errno::ECONNRESET,
        Errno::ECONNREFUSED,
        Errno::ETIMEDOUT,
        SocketError,
        OpenSSL::SSL::SSLError,
        # HTTP errors that are typically retryable
        Net::HTTPTooManyRequests,      # 429
        Net::HTTPInternalServerError,  # 500
        Net::HTTPBadGateway,          # 502
        Net::HTTPServiceUnavailable,  # 503
        Net::HTTPGatewayTimeout       # 504
      ].compact
    end

    def non_retryable_errors
      [
        Net::HTTPBadRequest,          # 400
        Net::HTTPUnauthorized,        # 401
        Net::HTTPForbidden,          # 403
        Net::HTTPNotFound,           # 404
        Net::HTTPUnprocessableEntity, # 422
        ArgumentError,
        JSON::ParserError
      ].compact
    end

    def calculate_delay(attempt)
      base_delay = configuration.retry_delay
      # Exponential backoff with jitter
      delay = base_delay * (2 ** (attempt - 1))
      # Add jitter (±25%)
      jitter = delay * 0.25 * (rand - 0.5)
      [(delay + jitter), 30].min # Cap at 30 seconds
    end
  end
end
