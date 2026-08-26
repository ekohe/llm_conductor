# frozen_string_literal: true

require 'faraday'
require 'net/http'
require 'time'

module LlmConductor
  module Clients
    module Concerns
      # Shared retry policy for provider API calls.
      #
      # +LlmConductor::Configuration+ has always declared +max_retries+ and
      # +retry_delay+; this concern is what makes them mean something. It is mixed
      # into BaseClient, so every provider goes through the same policy and the two
      # configuration knobs behave identically everywhere.
      #
      # Only failures that a second identical request can plausibly fix are retried:
      # the rate-limit and overload statuses in RETRYABLE_STATUSES, plus the
      # connection/read timeout classes in TRANSPORT_ERRORS. Everything else —
      # notably 400/401/403/404 and any other 4xx — surfaces on the first attempt,
      # because retrying a malformed request or a bad credential only wastes time.
      #
      # Backoff is exponential and seeded from +retry_delay+:
      #
      #   delay = min(retry_delay * 2**(attempt - 1), MAX_BACKOFF_SECONDS)
      #   delay += delay * JITTER_RATIO * rand
      #
      # The jitter is additive, so a retry never fires sooner than configured, but
      # concurrent workers hitting the same shared quota pool stop retrying in
      # lockstep. A +Retry-After+ header, when the API sends one, replaces the
      # computed backoff (still jittered, still capped).
      module Retryable
        # Statuses worth a second attempt: rate limiting and transient overload.
        RETRYABLE_STATUSES = [408, 429, 500, 502, 503, 504].freeze

        # Transport-level failures, which carry no HTTP status at all.
        TRANSPORT_ERRORS = [
          Faraday::ConnectionFailed,
          Faraday::TimeoutError,
          Faraday::NilStatusError,
          Net::OpenTimeout,
          Net::ReadTimeout,
          Errno::ECONNRESET,
          Errno::ECONNREFUSED
        ].freeze

        # Ceiling for the computed exponential backoff, so a generous retry_delay
        # cannot park a worker for minutes.
        MAX_BACKOFF_SECONDS = 30.0

        # Ceiling for a server-supplied Retry-After. A library should not block its
        # caller for longer than this; past it, failing fast is the better answer.
        MAX_RETRY_AFTER_SECONDS = 60.0

        # Additive jitter, as a fraction of the delay: 0.25 spreads retries over
        # [delay, delay * 1.25).
        JITTER_RATIO = 0.25

        # All backoff waiting funnels through here. Keeping it a single module
        # method gives tests one seam to observe instead of stubbing Kernel#sleep on
        # every client, and leaves one place to change should a caller ever need a
        # non-blocking scheduler.
        def self.sleep_for(seconds)
          sleep(seconds)
        end

        private

        # Run the block, retrying transient failures per the configured policy.
        #
        # @yield the provider request to attempt
        # @return [Object] the block's value
        # @raise [StandardError] the last error, once attempts are exhausted or the
        #   failure is not retryable
        def with_retries
          attempt = 0
          max_attempts = retry_attempts

          begin
            attempt += 1
            yield
          rescue StandardError => e
            raise if attempt >= max_attempts || !retryable_error?(e)

            delay = retry_delay_for(e, attempt)
            log_retry(e, attempt, max_attempts, delay)
            Retryable.sleep_for(delay)
            retry
          end
        end

        # Total attempts allowed, including the first one.
        #
        # +max_retries+ is read as a total attempt budget (matching the hardcoded
        # loops this concern replaced), so the default of 3 means one initial call
        # plus at most two retries. Anything below 1 degrades to a single attempt.
        def retry_attempts
          [configuration.max_retries.to_i, 1].max
        end

        # @return [Boolean] whether an identical retry could plausibly succeed
        def retryable_error?(error)
          err = unwrap_error(error)
          status = http_status(err)
          return RETRYABLE_STATUSES.include?(status) unless status.nil?

          TRANSPORT_ERRORS.any? { |klass| err.is_a?(klass) }
        end

        # Seconds to wait before the next attempt.
        def retry_delay_for(error, attempt)
          apply_jitter(retry_after_seconds(error) || backoff_seconds(attempt))
        end

        # Exponential backoff seeded from configuration.retry_delay.
        def backoff_seconds(attempt)
          base = configuration.retry_delay.to_f * (2**(attempt - 1))
          [base, MAX_BACKOFF_SECONDS].min
        end

        # Spread concurrent retries without ever firing earlier than asked.
        def apply_jitter(seconds)
          seconds + (seconds * JITTER_RATIO * rand)
        end

        # Honour a Retry-After header when the API sends a usable one.
        # @return [Float, nil] seconds to wait, or nil when absent/unparseable
        def retry_after_seconds(error)
          raw = header_value(response_headers(error), 'retry-after').to_s.strip
          return if raw.empty?

          seconds = parse_retry_after(raw)
          seconds&.clamp(0.0, MAX_RETRY_AFTER_SECONDS)
        end

        # Retry-After is either a delay in seconds or an HTTP-date.
        def parse_retry_after(raw)
          return raw.to_f if raw.match?(/\A\d+(\.\d+)?\z/)

          Time.httpdate(raw) - Time.now
        rescue ArgumentError
          nil
        end

        # Log every retry through the gem's configured logger.
        #
        # Deliberately reports only the class/status, attempt and delay: the
        # exception's message and response carry the request URL, and for Gemini's
        # generative-language endpoint that URL embeds the API key as a query param.
        def log_retry(error, attempt, max_attempts, delay)
          err = unwrap_error(error)
          status = http_status(err)
          reason = status ? "HTTP #{status}" : err.class.name

          configuration.logger&.warn(
            "[LlmConductor::Clients::#{short_class_name}] transient #{reason} " \
            "on attempt #{attempt}/#{max_attempts}; retrying in #{format('%.2f', delay)}s"
          )
        end

        # Some clients wrap the transport error (gemini-ai re-raises Faraday errors
        # as Gemini::Errors::RequestError, keeping the original in #request).
        def unwrap_error(error)
          inner = error.respond_to?(:request) ? error.request : nil
          inner.is_a?(StandardError) ? inner : error
        end

        # @return [Integer, nil] HTTP status, or nil for transport-level failures
        def http_status(error)
          error.respond_to?(:response_status) ? error.response_status : nil
        end

        # @return [Hash, nil] response headers, when the error carries a response
        def response_headers(error)
          err = unwrap_error(error)
          err.respond_to?(:response_headers) ? err.response_headers : nil
        end

        # Case-insensitive header lookup that works for plain Hashes as well as
        # Faraday's own headers object.
        def header_value(headers, name)
          return unless headers.respond_to?(:to_h)

          _key, value = headers.to_h.find { |key, _| key.to_s.downcase == name }
          value
        end

        def short_class_name
          self.class.name.to_s.split('::').last
        end
      end
    end
  end
end
