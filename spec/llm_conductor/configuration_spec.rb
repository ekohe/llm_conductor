# frozen_string_literal: true

RSpec.describe LlmConductor::Configuration do
  subject(:config) { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(config.default_model).to eq('gpt-3.5-turbo')
      expect(config.default_vendor).to eq(:openai)
      expect(config.timeout).to eq(30)
      expect(config.max_retries).to eq(3)
      expect(config.retry_delay).to eq(1.0)
    end

    it 'initializes empty providers hash' do
      expect(config.providers).to eq({})
    end
  end

  describe '#add_provider' do
    it 'adds a provider configuration' do
      config.add_provider(:test, { api_key: 'test_key' })
      expect(config.providers[:test]).to eq({ api_key: 'test_key' })
    end
  end

  describe '#provider_config' do
    before do
      config.add_provider(:test, { api_key: 'test_key' })
    end

    it 'returns provider configuration' do
      expect(config.provider_config(:test)).to eq({ api_key: 'test_key' })
    end

    it 'raises error for unconfigured provider' do
      expect {
        config.provider_config(:unknown)
      }.to raise_error(LlmConductor::ConfigurationError, 'Provider unknown not configured')
    end
  end
end
