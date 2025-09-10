# frozen_string_literal: true

module LlmConductor
  class RetryPolicy
    attr_reader :max_retries, :base_delay, :max_delay, :backoff_factor, :jitter

    def initialize(max_retries: 3, base_delay: 1.0, max_delay: 30.0, backoff_factor: 2.0, jitter: true)
      @max_retries = max_retries
      @base_delay = base_delay
      @max_delay = max_delay
      @backoff_factor = backoff_factor
      @jitter = jitter
    end

    def should_retry?(attempt, error)
      return false if attempt > max_retries
      
      retryable_error?(error)
    end

    def calculate_delay(attempt)
      delay = base_delay * (backoff_factor ** (attempt - 1))
      delay = [delay, max_delay].min
      
      if jitter
        jitter_amount = delay * 0.1 * (rand - 0.5) * 2  # ±10% jitter
        delay += jitter_amount
      end
      
      [delay, 0].max
    end

    def retryable_error?(error)
      case error
      when Net::TimeoutError, Net::ReadTimeout, Net::OpenTimeout
        true
      when Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ETIMEDOUT
        true
      when SocketError, OpenSSL::SSL::SSLError
        true
      when StandardError
        # Check HTTP status codes if available
        if error.respond_to?(:response) && error.response
          status = error.response.code.to_i
          retryable_status_code?(status)
        else
          # Check error message for common retryable patterns
          retryable_message?(error.message)
        end
      else
        false
      end
    end

    private

    def retryable_status_code?(status)
      case status
      when 429, 500, 502, 503, 504
        true
      else
        false
      end
    end

    def retryable_message?(message)
      return false unless message
      
      retryable_patterns = [
        /timeout/i,
        /connection.*reset/i,
        /connection.*refused/i,
        /service.*unavailable/i,
        /rate.*limit/i,
        /too.*many.*requests/i
      ]
      
      retryable_patterns.any? { |pattern| message.match?(pattern) }
    end
  end
end
