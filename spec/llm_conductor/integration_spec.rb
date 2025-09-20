# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor do
  describe 'end-to-end integration tests' do
    let(:data) do
      {
        name: 'TechCorp',
        domain_name: 'techcorp.com',
        description: 'A leading AI technology company',
        industries: ['Artificial Intelligence', 'Software Development']
      }
    end

    before do
      described_class.configure do |config|
        config.anthropic_api_key = 'test_anthropic_key'
        config.openai_api_key = 'test_openai_key'
        config.openrouter_api_key = 'test_openrouter_key'
        config.ollama_address = 'http://localhost:11434'
      end
    end

    describe '.build_client + client.generate flow' do
      context 'with Anthropic client' do
        let(:mock_anthropic_client) { double('Anthropic::Client') }
        let(:mock_response) do
          double('response',
                 content: [double('content',
                                  text: 'TechCorp is a leading AI company specializing in software development.')])
        end
        let(:mock_encoder) { double('encoder', encode: %w[token1 token2 token3]) }

        before do
          allow(Anthropic::Client).to receive(:new).and_return(mock_anthropic_client)
          allow(mock_anthropic_client).to receive(:messages).and_return(double('messages', create: mock_response))
          allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
        end

        it 'creates Anthropic client and generates response successfully', :aggregate_failures do
          client = described_class.build_client(model: 'claude-3-5-sonnet-20241022', type: :summarize_description)
          result = client.generate(data:)

          expect(client).to be_a(LlmConductor::Clients::AnthropicClient)
          expect(result).to be_a(LlmConductor::Response)
          expect(result.output).to eq('TechCorp is a leading AI company specializing in software development.')
          expect(result.input_tokens).to eq(3)
          expect(result.output_tokens).to eq(3)
          expect(result.metadata[:prompt]).to include('TechCorp')
          expect(result.metadata[:prompt]).to include('techcorp.com')
        end
      end

      context 'with GPT client' do
        let(:mock_openai_client) { double('OpenAI::Client') }
        let(:api_response) do
          {
            'choices' => [
              { 'message' => { 'content' => 'TechCorp is a leading AI company specializing in software development.' } }
            ]
          }
        end
        let(:mock_encoder) { double('encoder', encode: %w[token1 token2 token3]) }

        before do
          allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
          allow(mock_openai_client).to receive(:chat).and_return(api_response)
          allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
        end

        it 'creates GPT client and generates response successfully', :aggregate_failures do
          client = described_class.build_client(model: 'gpt-4o-mini', type: :summarize_description)
          result = client.generate(data:)

          expect(client).to be_a(LlmConductor::Clients::GptClient)
          expect(result).to be_a(LlmConductor::Response)
          expect(result.output).to eq('TechCorp is a leading AI company specializing in software development.')
          expect(result.input_tokens).to eq(3)
          expect(result.output_tokens).to eq(3)
          expect(result.metadata[:prompt]).to include('TechCorp')
          expect(result.metadata[:prompt]).to include('techcorp.com')
        end
      end

      context 'with OpenRouter client' do
        let(:mock_openai_client) { double('OpenAI::Client') }
        let(:api_response) do
          {
            'choices' => [
              { 'message' => { 'content' => '["https://techcorp.com/about", "https://techcorp.com/products"]' } }
            ]
          }
        end
        let(:mock_encoder) { double('encoder', encode: %w[t1 t2]) }
        let(:link_data) do
          {
            htmls: '<html><a href="/about">About</a><a href="/products">Products</a></html>',
            current_url: 'https://techcorp.com'
          }
        end

        before do
          allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
          allow(mock_openai_client).to receive(:chat).and_return(api_response)
          allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
        end

        it 'creates OpenRouter client and generates featured links', :aggregate_failures do
          client = described_class.build_client(model: 'llama-3.2-90b', type: :featured_links, vendor: :openrouter)
          result = client.generate(data: link_data)

          expect(client).to be_a(LlmConductor::Clients::OpenrouterClient)
          expect(result.output).to include('techcorp.com')
          expect(OpenAI::Client).to have_received(:new).with(
            access_token: 'test_openrouter_key',
            uri_base: 'https://openrouter.ai/api/'
          )
        end
      end

      context 'with Ollama client' do
        let(:mock_ollama_client) { double('Ollama') }
        let(:api_response) do
          [{ 'response' => 'TechCorp operates in the AI and software development space.' }]
        end
        let(:mock_encoder) { double('encoder', encode: %w[a b c d]) }

        before do
          allow(Ollama).to receive(:new).and_return(mock_ollama_client)
          allow(mock_ollama_client).to receive(:generate).and_return(api_response)
          allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
        end

        it 'creates Ollama client and generates summary', :aggregate_failures do
          client = described_class.build_client(model: 'llama2', type: :summarize_description)
          result = client.generate(data:)

          expect(client).to be_a(LlmConductor::Clients::OllamaClient)
          expect(result.output).to eq('TechCorp operates in the AI and software development space.')
          expect(Ollama).to have_received(:new).with(
            credentials: { address: 'http://localhost:11434' },
            options: { server_sent_events: true }
          )
        end
      end
    end

    describe '.generate convenience method' do
      context 'with Anthropic' do
        let(:mock_anthropic_client) { double('Anthropic::Client') }
        let(:mock_response) do
          double('response', content: [double('content', text: 'Generated via convenience method')])
        end
        let(:mock_encoder) { double('encoder', encode: %w[token]) }

        before do
          allow(Anthropic::Client).to receive(:new).and_return(mock_anthropic_client)
          allow(mock_anthropic_client).to receive(:messages).and_return(double('messages', create: mock_response))
          allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
        end

        it 'generates content using the convenience method with Anthropic', :aggregate_failures do
          result = described_class.generate(
            model: 'claude-3-5-sonnet-20241022',
            type: :summarize_description,
            data:,
            vendor: :anthropic
          )

          expect(result).to be_a(LlmConductor::Response)
          expect(result.output).to eq('Generated via convenience method')
          expect(result.input_tokens).to eq(1)
          expect(result.output_tokens).to eq(1)
          expect(result.metadata[:prompt]).to include('TechCorp')
        end
      end

      context 'with GPT' do
        let(:mock_openai_client) { double('OpenAI::Client') }
        let(:api_response) do
          {
            'choices' => [
              { 'message' => { 'content' => 'Generated via convenience method' } }
            ]
          }
        end
        let(:mock_encoder) { double('encoder', encode: %w[token]) }

        before do
          allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
          allow(mock_openai_client).to receive(:chat).and_return(api_response)
          allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
        end

        it 'generates content using the convenience method', :aggregate_failures do
          result = described_class.generate(
            model: 'gpt-4o-mini',
            type: :summarize_description,
            data:,
            vendor: nil
          )

          expect(result).to be_a(LlmConductor::Response)
          expect(result.output).to eq('Generated via convenience method')
          expect(result.input_tokens).to eq(1)
          expect(result.output_tokens).to eq(1)
          expect(result.metadata[:prompt]).to include('TechCorp')
        end
      end
    end

    describe 'error handling scenarios' do
      context 'when Anthropic API call fails' do
        let(:mock_anthropic_client) { double('Anthropic::Client') }

        before do
          allow(Anthropic::Client).to receive(:new).and_return(mock_anthropic_client)
          messages_mock = double('messages')
          allow(messages_mock).to receive(:create).and_raise(StandardError, 'API Error')
          allow(mock_anthropic_client).to receive(:messages).and_return(messages_mock)
        end

        it 'handles API errors gracefully' do
          client = described_class.build_client(model: 'claude-3-5-sonnet-20241022', type: :summarize_description)

          result = client.generate(data:)
          expect(result).to be_a(LlmConductor::Response)
          expect(result.success?).to be false
          expect(result.metadata[:error]).to include('API Error')
        end
      end

      context 'when GPT API call fails' do
        let(:mock_openai_client) { double('OpenAI::Client') }

        before do
          allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
          allow(mock_openai_client).to receive(:chat).and_raise(StandardError, 'API Error')
        end

        it 'handles API errors gracefully' do
          client = described_class.build_client(model: 'gpt-4o-mini', type: :summarize_description)

          result = client.generate(data:)
          expect(result).to be_a(LlmConductor::Response)
          expect(result.success?).to be false
          expect(result.metadata[:error]).to include('API Error')
        end
      end

      context 'with invalid prompt type' do
        it 'handles unsupported prompt type gracefully' do
          client = described_class.build_client(model: 'gpt-4o-mini', type: :invalid_type)

          result = client.generate(data:)
          expect(result).to be_a(LlmConductor::Response)
          expect(result.success?).to be false
          expect(result.metadata).to have_key(:error)
        end
      end

      context 'with missing required data' do
        it 'handles missing template in custom prompts gracefully' do
          client = described_class.build_client(model: 'gpt-4o-mini', type: :custom)

          result = client.generate(data: {})
          expect(result).to be_a(LlmConductor::Response)
          expect(result.success?).to be false
          expect(result.metadata[:error]).to match(/KeyError|key not found/)
        end
      end
    end

    describe 'different prompt types integration' do
      let(:mock_openai_client) { double('OpenAI::Client') }
      let(:mock_encoder) { double('encoder', encode: ['token']) }

      before do
        allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
        allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
      end

      context 'with custom prompt type' do
        let(:custom_data) do
          {
            template: 'Analyze company: %<name>s (%<domain>s)',
            name: 'TechCorp',
            domain: 'techcorp.com'
          }
        end
        let(:api_response) do
          { 'choices' => [{ 'message' => { 'content' => 'Custom analysis result' } }] }
        end

        before do
          allow(mock_openai_client).to receive(:chat).and_return(api_response)
        end

        it 'handles custom prompt templates correctly' do
          result = described_class.generate(
            model: 'gpt-4o-mini',
            type: :custom,
            data: custom_data
          )

          expect(result.metadata[:prompt]).to eq('Analyze company: TechCorp (techcorp.com)')
          expect(result.output).to eq('Custom analysis result')
        end
      end

      context 'with summarize_htmls type' do
        let(:html_data) do
          { htmls: '<html><h1>TechCorp</h1><p>AI solutions provider</p></html>' }
        end
        let(:api_response) do
          {
            'choices' => [
              {
                'message' => {
                  'content' => '{"name": "TechCorp", "description": "AI solutions provider"}'
                }
              }
            ]
          }
        end

        before do
          allow(mock_openai_client).to receive(:chat).and_return(api_response)
        end

        it 'processes HTML summarization requests' do
          result = described_class.generate(
            model: 'gpt-4o-mini',
            type: :summarize_htmls,
            data: html_data
          )

          expect(result.metadata[:prompt]).to include('Extract useful information from the webpage')
          expect(result.output).to include('TechCorp')
        end
      end
    end

    describe 'configuration integration' do
      it 'respects Anthropic configuration changes across client creations' do
        mock_client = double('Anthropic::Client')
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)

        # Change configuration
        described_class.configure do |config|
          config.anthropic_api_key = 'updated_anthropic_key'
        end

        client = described_class.build_client(model: 'claude-3-5-sonnet-20241022', type: :summarize_description)
        # Trigger client instantiation by accessing the private client method
        client.send(:client)

        expect(Anthropic::Client).to have_received(:new).with(
          api_key: 'updated_anthropic_key'
        )
      end

      it 'respects OpenAI configuration changes across client creations' do
        mock_client = double('OpenAI::Client')
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)

        # Change configuration
        described_class.configure do |config|
          config.openai_api_key = 'updated_key'
        end

        client = described_class.build_client(model: 'gpt-4o-mini', type: :summarize_description)
        # Trigger client instantiation by accessing the private client method
        client.send(:client)

        expect(OpenAI::Client).to have_received(:new).with(
          access_token: 'updated_key'
        )
      end
    end
  end
end
