# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Configuration do
  subject(:config) { described_class.new }

  describe 'initialization' do
    it 'sets default configuration values' do
      expect(config.default_model).to eq('gpt-5-mini')
      expect(config.default_vendor).to eq(:openai)
      expect(config.timeout).to eq(30)
      expect(config.max_retries).to eq(3)
      expect(config.retry_delay).to eq(1.0)
      expect(config.providers).to be_a(Hash)
    end
  end

  describe 'provider configuration methods' do
    describe '#openai' do
      it 'configures OpenAI provider with API key' do
        config.openai(api_key: 'test_key')
        provider_config = config.provider_config(:openai)

        expect(provider_config[:api_key]).to eq('test_key')
      end

      it 'configures OpenAI provider with organization' do
        config.openai(api_key: 'test_key', organization: 'test_org')
        provider_config = config.provider_config(:openai)

        expect(provider_config[:api_key]).to eq('test_key')
        expect(provider_config[:organization]).to eq('test_org')
      end

      it 'uses environment variable if not provided' do
        ENV['OPENAI_API_KEY'] = 'env_key'
        config.openai
        provider_config = config.provider_config(:openai)

        expect(provider_config[:api_key]).to eq('env_key')
      end
    end

    describe '#openrouter' do
      it 'configures OpenRouter provider' do
        config.openrouter(api_key: 'router_key')
        provider_config = config.provider_config(:openrouter)

        expect(provider_config[:api_key]).to eq('router_key')
      end
    end

    describe '#ollama' do
      it 'configures Ollama provider with custom base URL' do
        config.ollama(base_url: 'http://custom.ollama.com')
        provider_config = config.provider_config(:ollama)

        expect(provider_config[:base_url]).to eq('http://custom.ollama.com')
      end

      it 'uses default base URL when not provided' do
        # Temporarily clear the environment variable for this test
        original_ollama_address = ENV['OLLAMA_ADDRESS']
        ENV['OLLAMA_ADDRESS'] = nil

        config.ollama
        provider_config = config.provider_config(:ollama)

        expect(provider_config[:base_url]).to eq('http://localhost:11434')
      ensure
        # Restore the original environment variable
        ENV['OLLAMA_ADDRESS'] = original_ollama_address
      end
    end

    describe '#groq' do
      it 'configures Groq provider with API key' do
        config.groq(api_key: 'groq_key')
        provider_config = config.provider_config(:groq)

        expect(provider_config[:api_key]).to eq('groq_key')
      end

      it 'uses environment variable if not provided' do
        ENV['GROQ_API_KEY'] = 'env_groq_key'
        config.groq
        provider_config = config.provider_config(:groq)

        expect(provider_config[:api_key]).to eq('env_groq_key')
      end
    end
  end

  describe 'legacy compatibility methods' do
    it 'provides backward compatibility for openai_api_key' do
      config.openai_api_key = 'legacy_key'
      expect(config.openai_api_key).to eq('legacy_key')
      expect(config.provider_config(:openai)[:api_key]).to eq('legacy_key')
    end

    it 'provides backward compatibility for openrouter_api_key' do
      config.openrouter_api_key = 'legacy_router_key'
      expect(config.openrouter_api_key).to eq('legacy_router_key')
      expect(config.provider_config(:openrouter)[:api_key]).to eq('legacy_router_key')
    end

    it 'provides backward compatibility for ollama_address' do
      config.ollama_address = 'http://legacy.ollama.com'
      expect(config.ollama_address).to eq('http://legacy.ollama.com')
      expect(config.provider_config(:ollama)[:base_url]).to eq('http://legacy.ollama.com')
    end

    it 'provides backward compatibility for groq_api_key' do
      config.groq_api_key = 'legacy_groq_key'
      expect(config.groq_api_key).to eq('legacy_groq_key')
      expect(config.provider_config(:groq)[:api_key]).to eq('legacy_groq_key')
    end
  end

  describe 'environment variable initialization' do
    it 'auto-configures providers from environment variables', :with_test_config do
      ENV['OPENAI_API_KEY'] = 'env_openai_key'
      ENV['OPENROUTER_API_KEY'] = 'env_openrouter_key'
      ENV['GROQ_API_KEY'] = 'env_groq_key'
      ENV['OLLAMA_ADDRESS'] = 'http://env.ollama.com'

      config = described_class.new

      expect(config.provider_config(:openai)[:api_key]).to eq('env_openai_key')
      expect(config.provider_config(:openrouter)[:api_key]).to eq('env_openrouter_key')
      expect(config.provider_config(:groq)[:api_key]).to eq('env_groq_key')
      expect(config.provider_config(:ollama)[:base_url]).to eq('http://env.ollama.com')
    end
  end

  describe '#provider_config' do
    it 'returns empty hash for unconfigured provider' do
      expect(config.provider_config(:unknown)).to eq({})
    end

    it 'returns provider configuration' do
      config.openai(api_key: 'test_key', organization: 'test_org')
      provider_config = config.provider_config(:openai)

      expect(provider_config).to eq(api_key: 'test_key', organization: 'test_org')
    end
  end
end

RSpec.describe LlmConductor do
  describe '.configure' do
    it 'yields the configuration instance for block configuration' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(LlmConductor::Configuration)

      described_class.configure do |config|
        expect(config).to be_a(LlmConductor::Configuration)
      end
    end

    it 'allows configuring multiple providers in block' do
      described_class.configure do |config|
        config.default_model = 'gpt-4'
        config.timeout = 60
        config.openai(api_key: 'test_openai')
        config.openrouter(api_key: 'test_openrouter')
      end

      expect(described_class.configuration.default_model).to eq('gpt-4')
      expect(described_class.configuration.timeout).to eq(60)
      expect(described_class.configuration.provider_config(:openai)[:api_key]).to eq('test_openai')
      expect(described_class.configuration.provider_config(:openrouter)[:api_key]).to eq('test_openrouter')
    end
  end

  describe '.configuration' do
    it 'returns the same configuration instance' do
      config1 = described_class.configuration
      config2 = described_class.configuration

      expect(config1).to be(config2)
    end
  end
end
