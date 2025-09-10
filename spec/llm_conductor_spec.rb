# frozen_string_literal: true

RSpec.describe LlmConductor do
  it 'has a version number' do
    expect(LlmConductor::VERSION).not_to be nil
  end

  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(LlmConductor.configuration).to be_a(LlmConductor::Configuration)
    end
  end

  describe '.configure' do
    it 'yields the configuration' do
      expect { |b| LlmConductor.configure(&b) }.to yield_with_args(LlmConductor.configuration)
    end

    it 'allows setting configuration options' do
      LlmConductor.configure do |config|
        config.default_model = 'test-model'
        config.timeout = 60
      end

      expect(LlmConductor.configuration.default_model).to eq('test-model')
      expect(LlmConductor.configuration.timeout).to eq(60)
    end
  end

  describe '.client' do
    it 'creates a client through ClientFactory' do
      expect(LlmConductor::ClientFactory).to receive(:build).with(
        model: 'gpt-3.5-turbo',
        type: nil,
        vendor: nil,
        configuration: LlmConductor.configuration
      )

      LlmConductor.client(model: 'gpt-3.5-turbo')
    end
  end

  describe '.generate' do
    let(:mock_client) { double('client') }
    let(:mock_response) { double('response') }

    before do
      allow(LlmConductor).to receive(:client).and_return(mock_client)
    end

    context 'with prompt' do
      it 'calls generate_from_prompt on the client' do
        expect(mock_client).to receive(:generate_from_prompt).with(prompt: 'test prompt').and_return(mock_response)

        result = LlmConductor.generate(model: 'gpt-3.5-turbo', prompt: 'test prompt')
        expect(result).to eq(mock_response)
      end
    end

    context 'with data and type' do
      it 'calls generate on the client' do
        expect(mock_client).to receive(:generate).with(data: { test: 'data' }).and_return(mock_response)

        result = LlmConductor.generate(model: 'gpt-3.5-turbo', data: { test: 'data' }, type: :test)
        expect(result).to eq(mock_response)
      end
    end

    context 'without prompt or data+type' do
      it 'raises ArgumentError' do
        expect {
          LlmConductor.generate(model: 'gpt-3.5-turbo')
        }.to raise_error(ArgumentError, 'Either prompt or (data + type) must be provided')
      end
    end
  end
end
