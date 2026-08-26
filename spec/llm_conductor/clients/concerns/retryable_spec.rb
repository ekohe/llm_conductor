# frozen_string_literal: true

require 'spec_helper'
require 'logger'

RSpec.describe LlmConductor::Clients::Concerns::Retryable do
  # The concern is the unit under test; GeminiClient is just the vehicle that
  # carries it, chosen because Vertex 429s are what motivated the policy.
  let(:client) { LlmConductor::Clients::GeminiClient.new(model:, type: :direct) }
  let(:model) { 'gemini-2.5-flash' }
  let(:prompt) { 'Ping' }
  let(:retryable) { described_class }
  let(:logger) { instance_double(Logger, debug: nil, warn: nil) }

  # Faraday raises a status-specific subclass; only the status matters to the
  # policy, so anything without a dedicated class falls back to the 4xx/5xx base.
  ERROR_CLASSES = {
    400 => Faraday::BadRequestError,
    401 => Faraday::UnauthorizedError,
    403 => Faraday::ForbiddenError,
    404 => Faraday::ResourceNotFound,
    408 => Faraday::RequestTimeoutError,
    422 => Faraday::UnprocessableEntityError,
    429 => Faraday::TooManyRequestsError
  }.freeze

  # Vertex answers a saturated per-model quota pool with a bare Faraday 429:
  # gemini-ai only wraps 5xx, so this is what actually reaches the client.
  def faraday_error(status, headers: {})
    ERROR_CLASSES.fetch(status, Faraday::ServerError).new(nil, { status:, headers:, body: '' })
  end

  # gemini-ai re-raises Faraday 5xx as Gemini::Errors::RequestError, keeping the
  # original Faraday error in #request.
  def wrapped_error(status, headers: {})
    Gemini::Errors::RequestError.new(
      'the server responded with an error', request: faraday_error(status, headers:), payload: {}
    )
  end

  # Fail the first attempt with +error+, succeed on the second.
  def fail_once_then_succeed(target, error)
    calls = 0
    allow(target).to receive(:generate_content) do
      calls += 1
      raise error if calls == 1

      'recovered'
    end
    -> { calls }
  end

  before do
    LlmConductor.configuration.gemini_api_key = 'test_api_key'
    LlmConductor.configuration.logger = logger
    # rand is the only nondeterminism in the backoff; pin it unless a test says otherwise.
    allow(client).to receive(:rand).and_return(0.0)
  end

  describe 'retryable failures' do
    [429, 503, 500, 502, 504, 408].each do |status|
      it "retries HTTP #{status} and returns the eventual success" do
        calls = fail_once_then_succeed(client, faraday_error(status))

        response = client.generate_simple(prompt:)

        expect(calls.call).to eq(2)
        expect(response.output).to eq('recovered')
        expect(response).to be_success
      end
    end

    it 'retries a Faraday 5xx wrapped in Gemini::Errors::RequestError' do
      calls = fail_once_then_succeed(client, wrapped_error(503))

      expect(client.generate_simple(prompt:).output).to eq('recovered')
      expect(calls.call).to eq(2)
    end

    {
      Faraday::ConnectionFailed => -> { Faraday::ConnectionFailed.new('connection refused') },
      Faraday::TimeoutError => -> { Faraday::TimeoutError.new('execution expired') },
      Faraday::NilStatusError => -> { Faraday::NilStatusError.new(nil, { status: nil, headers: {}, body: '' }) },
      Net::ReadTimeout => -> { Net::ReadTimeout.new },
      Net::OpenTimeout => -> { Net::OpenTimeout.new },
      Errno::ECONNRESET => -> { Errno::ECONNRESET.new }
    }.each do |error_class, build_error|
      it "retries #{error_class}, which carries no HTTP status" do
        calls = fail_once_then_succeed(client, build_error.call)

        expect(client.generate_simple(prompt:).output).to eq('recovered')
        expect(calls.call).to eq(2)
      end
    end
  end

  describe 'non-retryable failures' do
    [400, 401, 403, 404, 422].each do |status|
      it "surfaces HTTP #{status} immediately, without a second call" do
        allow(client).to receive(:generate_content).and_raise(faraday_error(status))

        response = client.generate_simple(prompt:)

        expect(client).to have_received(:generate_content).once
        expect(response).not_to be_success
        expect(retryable).not_to have_received(:sleep_for)
      end
    end

    it 'does not retry an unrecognised StandardError' do
      allow(client).to receive(:generate_content).and_raise(ArgumentError, 'bad params')

      response = client.generate_simple(prompt:)

      expect(client).to have_received(:generate_content).once
      expect(response.metadata[:error_class]).to eq('ArgumentError')
    end

    it 'does not retry an SSL failure, which will not fix itself' do
      allow(client).to receive(:generate_content).and_raise(Faraday::SSLError, 'cert verify failed')

      client.generate_simple(prompt:)

      expect(client).to have_received(:generate_content).once
      expect(retryable).not_to have_received(:sleep_for)
    end
  end

  describe 'max_retries' do
    it 'makes exactly max_retries attempts before giving up' do
      LlmConductor.configuration.max_retries = 4
      allow(client).to receive(:generate_content).and_raise(faraday_error(429))

      response = client.generate_simple(prompt:)

      expect(client).to have_received(:generate_content).exactly(4).times
      expect(retryable).to have_received(:sleep_for).exactly(3).times
      expect(response).not_to be_success
    end

    it 'makes a single attempt when max_retries is 1' do
      LlmConductor.configuration.max_retries = 1
      allow(client).to receive(:generate_content).and_raise(faraday_error(429))

      client.generate_simple(prompt:)

      expect(client).to have_received(:generate_content).once
      expect(retryable).not_to have_received(:sleep_for)
    end

    it 'degrades to a single attempt when max_retries is 0' do
      LlmConductor.configuration.max_retries = 0
      allow(client).to receive(:generate_content).and_raise(faraday_error(429))

      client.generate_simple(prompt:)

      expect(client).to have_received(:generate_content).once
    end

    it 'uses three attempts by default' do
      allow(client).to receive(:generate_content).and_raise(faraday_error(429))

      client.generate_simple(prompt:)

      expect(client).to have_received(:generate_content).exactly(3).times
    end
  end

  describe 'backoff' do
    before do
      LlmConductor.configuration.max_retries = 4
      allow(client).to receive(:generate_content).and_raise(faraday_error(503))
    end

    it 'doubles the delay on each attempt, starting from retry_delay' do
      LlmConductor.configuration.retry_delay = 1.0

      client.generate_simple(prompt:)

      expect(retryable).to have_received(:sleep_for).with(1.0).ordered
      expect(retryable).to have_received(:sleep_for).with(2.0).ordered
      expect(retryable).to have_received(:sleep_for).with(4.0).ordered
    end

    it 'scales the whole curve with retry_delay' do
      LlmConductor.configuration.retry_delay = 0.25

      client.generate_simple(prompt:)

      expect(retryable).to have_received(:sleep_for).with(0.25).ordered
      expect(retryable).to have_received(:sleep_for).with(0.5).ordered
      expect(retryable).to have_received(:sleep_for).with(1.0).ordered
    end

    it 'caps the computed backoff at MAX_BACKOFF_SECONDS' do
      LlmConductor.configuration.retry_delay = 100.0

      client.generate_simple(prompt:)

      expect(retryable).to have_received(:sleep_for)
        .with(described_class::MAX_BACKOFF_SECONDS).exactly(3).times
    end

    it 'jitters upward only, so a retry never fires earlier than configured' do
      LlmConductor.configuration.retry_delay = 1.0
      allow(client).to receive(:rand).and_return(1.0)

      client.generate_simple(prompt:)

      # base * (1 + JITTER_RATIO) for base 1.0, 2.0, 4.0
      expect(retryable).to have_received(:sleep_for).with(1.25).ordered
      expect(retryable).to have_received(:sleep_for).with(2.5).ordered
      expect(retryable).to have_received(:sleep_for).with(5.0).ordered
    end

    it 'keeps a real jittered delay within one JITTER_RATIO of the base' do
      LlmConductor.configuration.retry_delay = 1.0
      allow(client).to receive(:rand).and_call_original

      client.generate_simple(prompt:)

      expect(retryable).to have_received(:sleep_for)
        .with(a_value_between(1.0, 1.0 + described_class::JITTER_RATIO)).at_least(:once)
    end
  end

  describe 'Retry-After' do
    before do
      LlmConductor.configuration.max_retries = 2
      LlmConductor.configuration.retry_delay = 1.0
    end

    it 'prefers a Retry-After delay in seconds over the computed backoff' do
      allow(client).to receive(:generate_content)
        .and_raise(faraday_error(429, headers: { 'Retry-After' => '7' }))

      client.generate_simple(prompt:)

      expect(retryable).to have_received(:sleep_for).with(7.0)
    end

    it 'matches the header name case-insensitively' do
      allow(client).to receive(:generate_content)
        .and_raise(faraday_error(503, headers: { 'retry-after' => '3' }))

      client.generate_simple(prompt:)

      expect(retryable).to have_received(:sleep_for).with(3.0)
    end

    it 'reads Retry-After through an error wrapped by gemini-ai' do
      allow(client).to receive(:generate_content)
        .and_raise(wrapped_error(503, headers: { 'Retry-After' => '5' }))

      client.generate_simple(prompt:)

      expect(retryable).to have_received(:sleep_for).with(5.0)
    end

    it 'accepts an HTTP-date Retry-After' do
      allow(client).to receive(:generate_content)
        .and_raise(faraday_error(429, headers: { 'Retry-After' => (Time.now + 4).httpdate }))

      client.generate_simple(prompt:)

      expect(retryable).to have_received(:sleep_for).with(a_value_between(2.0, 5.0))
    end

    it 'caps an unreasonably long Retry-After' do
      allow(client).to receive(:generate_content)
        .and_raise(faraday_error(429, headers: { 'Retry-After' => '900' }))

      client.generate_simple(prompt:)

      expect(retryable).to have_received(:sleep_for).with(described_class::MAX_RETRY_AFTER_SECONDS)
    end

    it 'falls back to the computed backoff when Retry-After is unparseable' do
      allow(client).to receive(:generate_content)
        .and_raise(faraday_error(429, headers: { 'Retry-After' => 'soon-ish' }))

      client.generate_simple(prompt:)

      expect(retryable).to have_received(:sleep_for).with(1.0)
    end
  end

  describe 'logging' do
    before do
      LlmConductor.configuration.max_retries = 2
      LlmConductor.configuration.retry_delay = 1.0
    end

    it 'warns once per retry with the attempt, status and delay' do
      allow(client).to receive(:generate_content).and_raise(faraday_error(429))

      client.generate_simple(prompt:)

      expect(logger).to have_received(:warn).with(
        '[LlmConductor::Clients::GeminiClient] transient HTTP 429 on attempt 1/2; retrying in 1.00s'
      ).once
    end

    it 'names the error class when there is no HTTP status' do
      allow(client).to receive(:generate_content).and_raise(Faraday::TimeoutError)

      client.generate_simple(prompt:)

      expect(logger).to have_received(:warn).with(%r{transient Faraday::TimeoutError on attempt 1/2})
    end

    it 'never logs the API key, which Gemini carries in the request URL' do
      leaky = faraday_error(429)
      allow(leaky).to receive(:message).and_return(
        'the server responded with status 429 for https://example.test/v1/models?key=test_api_key'
      )
      allow(client).to receive(:generate_content).and_raise(leaky)

      client.generate_simple(prompt:)

      expect(logger).not_to have_received(:warn).with(/test_api_key/)
    end

    it 'stays quiet when no logger is configured' do
      LlmConductor.configuration.logger = nil
      allow(client).to receive(:generate_content).and_raise(faraday_error(429))

      expect { client.generate_simple(prompt:) }.not_to raise_error
    end
  end

  describe 'reach' do
    it 'applies to every client, because the policy lives in BaseClient' do
      [LlmConductor::Clients::GeminiClient, LlmConductor::Clients::OpenrouterClient,
       LlmConductor::Clients::ZaiClient, LlmConductor::Clients::GptClient,
       LlmConductor::Clients::AnthropicClient, LlmConductor::Clients::GroqClient,
       LlmConductor::Clients::OllamaClient].each do |client_class|
        provider_client = client_class.new(model: 'test-model', type: :direct)
        allow(provider_client).to receive(:rand).and_return(0.0)
        calls = fail_once_then_succeed(provider_client, faraday_error(503))

        expect(provider_client.generate_simple(prompt:).output).to eq('recovered')
        expect(calls.call).to eq(2)
      end
    end

    it 'covers template-based generate, not just generate_simple' do
      templated = LlmConductor::Clients::GeminiClient.new(model:, type: :analyze_content)
      allow(templated).to receive(:rand).and_return(0.0)
      calls = fail_once_then_succeed(templated, faraday_error(429))

      response = templated.generate(data: { content: 'text to analyse' })

      expect(response.output).to eq('recovered')
      expect(calls.call).to eq(2)
    end
  end
end
