# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Clients::GeminiClient do
  let(:model) { 'gemini-2.5-flash' }
  let(:type) { :analyze_content }
  let(:client) { described_class.new(model:, type:) }

  before do
    LlmConductor.configuration.gemini_api_key = 'test_api_key'
  end

  describe 'inheritance' do
    it 'inherits from BaseClient' do
      expect(client).to be_a(LlmConductor::Clients::BaseClient)
    end

    it 'includes Prompts module through inheritance' do
      expect(client).to respond_to(:prompt_analyze_content)
    end

    it 'includes VisionSupport concern' do
      expect(client).to be_a(LlmConductor::Clients::Concerns::VisionSupport)
    end
  end

  describe '#generate_content (private)' do
    let(:prompt) { 'Test prompt for Gemini' }
    let(:mock_gemini_client) { double('Gemini') }
    let(:api_response) do
      {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => 'Generated response from Gemini' }
              ]
            }
          }
        ]
      }
    end

    before do
      allow(client).to receive(:client).and_return(mock_gemini_client)
      allow(mock_gemini_client).to receive(:generate_content).and_return(api_response)
    end

    it 'calls Gemini API with correct parameters' do
      client.send(:generate_content, prompt)

      expect(mock_gemini_client).to have_received(:generate_content).with(
        {
          contents: [
            { role: 'user', parts: [{ text: prompt }] }
          ]
        }
      )
    end

    it 'extracts and returns the content from API response' do
      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from Gemini')
    end

    it 'handles nested response structure with dig' do
      custom_response = {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => 'Custom Gemini response' }
              ]
            }
          }
        ]
      }
      allow(mock_gemini_client).to receive(:generate_content).and_return(custom_response)

      result = client.send(:generate_content, prompt)

      expect(result).to eq('Custom Gemini response')
    end
  end

  describe 'params support' do
    let(:params) { { temperature: 0.3, top_p: 0.85, max_tokens: 1024 } }
    let(:client_with_params) { described_class.new(model:, type:, params:) }
    let(:prompt) { 'Test prompt with params' }
    let(:mock_gemini_client) { double('Gemini') }
    let(:api_response) do
      {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => 'Response with params' }
              ]
            }
          }
        ]
      }
    end

    before do
      allow(client_with_params).to receive(:client).and_return(mock_gemini_client)
      allow(mock_gemini_client).to receive(:generate_content).and_return(api_response)
    end

    it 'stores params' do
      expect(client_with_params.params).to eq(params)
    end

    it 'includes generationConfig in the payload when params are present' do
      client_with_params.send(:generate_content, prompt)

      expect(mock_gemini_client).to have_received(:generate_content).with(
        {
          contents: [
            { role: 'user', parts: [{ text: prompt }] }
          ],
          generationConfig: {
            temperature: 0.3,
            topP: 0.85,
            maxOutputTokens: 1024
          }
        }
      )
    end

    it 'maps snake_case keys to camelCase Gemini keys' do
      client_with_all_params = described_class.new(
        model:, type:,
        params: { temperature: 0.5, top_p: 0.9, top_k: 40, max_output_tokens: 2048 }
      )
      allow(client_with_all_params).to receive(:client).and_return(mock_gemini_client)

      client_with_all_params.send(:generate_content, prompt)

      expect(mock_gemini_client).to have_received(:generate_content).with(
        hash_including(
          generationConfig: {
            temperature: 0.5,
            topP: 0.9,
            topK: 40,
            maxOutputTokens: 2048
          }
        )
      )
    end

    it 'omits generationConfig when no params are provided' do
      allow(client).to receive(:client).and_return(mock_gemini_client)

      client.send(:generate_content, prompt)

      expect(mock_gemini_client).to have_received(:generate_content).with(
        {
          contents: [
            { role: 'user', parts: [{ text: prompt }] }
          ]
        }
      )
    end

    it 'omits generationConfig when params contain no mapped keys' do
      client_unknown = described_class.new(model:, type:, params: { unknown_key: 'value' })
      allow(client_unknown).to receive(:client).and_return(mock_gemini_client)

      client_unknown.send(:generate_content, prompt)

      expect(mock_gemini_client).to have_received(:generate_content).with(
        {
          contents: [
            { role: 'user', parts: [{ text: prompt }] }
          ]
        }
      )
    end

    it 'handles string keys in params by converting to symbols' do
      client_string_keys = described_class.new(
        model:, type:,
        params: { 'temperature' => 0.7, 'top_p' => 0.8 }
      )
      allow(client_string_keys).to receive(:client).and_return(mock_gemini_client)

      client_string_keys.send(:generate_content, prompt)

      expect(mock_gemini_client).to have_received(:generate_content).with(
        hash_including(
          generationConfig: {
            temperature: 0.7,
            topP: 0.8
          }
        )
      )
    end
  end

  describe 'generationConfig key mapping' do
    let(:prompt) { 'Test prompt for generationConfig' }
    let(:mock_gemini_client) { double('Gemini') }
    let(:api_response) do
      { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Response' }] } }] }
    end

    before do
      allow(mock_gemini_client).to receive(:generate_content).and_return(api_response)
    end

    # Sends a real request through the client so assertions cover the payload the
    # Gemini API actually receives, not just the private builder.
    def send_with(params)
      instance = described_class.new(model:, type:, params:)
      allow(instance).to receive(:client).and_return(mock_gemini_client)
      instance.send(:generate_content, prompt)
    end

    def generation_config_from_last_call
      payload = nil
      expect(mock_gemini_client).to have_received(:generate_content) { |arg| payload = arg }
      payload[:generationConfig]
    end

    it 'maps every supported key to its camelCase Gemini equivalent' do
      send_with(
        temperature: 0.4,
        top_p: 0.85,
        top_k: 32,
        max_tokens: 512,
        candidate_count: 2,
        stop_sequences: %w[STOP END]
      )

      expect(generation_config_from_last_call).to eq(
        temperature: 0.4,
        topP: 0.85,
        topK: 32,
        maxOutputTokens: 512,
        candidateCount: 2,
        stopSequences: %w[STOP END]
      )
    end

    it 'maps max_output_tokens to maxOutputTokens' do
      send_with(max_output_tokens: 4096)

      expect(generation_config_from_last_call).to eq(maxOutputTokens: 4096)
    end
  end

  describe 'thinking config support' do
    let(:prompt) { 'Test prompt with thinking config' }
    let(:mock_gemini_client) { double('Gemini') }
    let(:api_response) do
      { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Response' }] } }] }
    end

    before do
      allow(mock_gemini_client).to receive(:generate_content).and_return(api_response)
    end

    def send_with(params)
      instance = described_class.new(model:, type:, params:)
      allow(instance).to receive(:client).and_return(mock_gemini_client)
      instance.send(:generate_content, prompt)
    end

    it 'nests thinking_config under generationConfig.thinkingConfig' do
      send_with(thinking_config: { thinking_level: 'minimal' })

      expect(mock_gemini_client).to have_received(:generate_content).with(
        {
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { thinkingConfig: { thinkingLevel: 'minimal' } }
        }
      )
    end

    it 'accepts a flat thinking_level convenience key' do
      send_with(thinking_level: 'minimal')

      expect(mock_gemini_client).to have_received(:generate_content).with(
        hash_including(generationConfig: { thinkingConfig: { thinkingLevel: 'minimal' } })
      )
    end

    it 'accepts thinking_budget' do
      send_with(thinking_budget: 0)

      expect(mock_gemini_client).to have_received(:generate_content).with(
        hash_including(generationConfig: { thinkingConfig: { thinkingBudget: 0 } })
      )
    end

    it 'accepts include_thoughts' do
      send_with(include_thoughts: true)

      expect(mock_gemini_client).to have_received(:generate_content).with(
        hash_including(generationConfig: { thinkingConfig: { includeThoughts: true } })
      )
    end

    it 'accepts camelCase API keys as given' do
      send_with(thinkingConfig: { thinkingLevel: 'high', thinkingBudget: 2048 })

      expect(mock_gemini_client).to have_received(:generate_content).with(
        hash_including(
          generationConfig: { thinkingConfig: { thinkingLevel: 'high', thinkingBudget: 2048 } }
        )
      )
    end

    it 'accepts string keys' do
      send_with('thinking_config' => { 'thinking_level' => 'minimal' })

      expect(mock_gemini_client).to have_received(:generate_content).with(
        hash_including(generationConfig: { thinkingConfig: { thinkingLevel: 'minimal' } })
      )
    end

    it 'combines thinking config with the other generation params' do
      send_with(temperature: 0.2, max_tokens: 256, thinking_level: 'minimal')

      expect(mock_gemini_client).to have_received(:generate_content).with(
        hash_including(
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 256,
            thinkingConfig: { thinkingLevel: 'minimal' }
          }
        )
      )
    end

    it 'merges the flat and nested forms' do
      send_with(thinking_config: { thinking_budget: 1024 }, thinking_level: 'low')

      expect(mock_gemini_client).to have_received(:generate_content).with(
        hash_including(
          generationConfig: { thinkingConfig: { thinkingBudget: 1024, thinkingLevel: 'low' } }
        )
      )
    end
  end

  describe 'unmapped params' do
    let(:prompt) { 'Test prompt with an unmapped param' }
    let(:mock_gemini_client) { double('Gemini') }
    let(:logger) { instance_double(Logger, warn: nil) }
    let(:api_response) do
      { 'candidates' => [{ 'content' => { 'parts' => [{ 'text' => 'Response' }] } }] }
    end

    before do
      LlmConductor.configuration.logger = logger
      allow(mock_gemini_client).to receive(:generate_content).and_return(api_response)
    end

    def send_with(params)
      instance = described_class.new(model:, type:, params:)
      allow(instance).to receive(:client).and_return(mock_gemini_client)
      instance.send(:generate_content, prompt)
    end

    it 'warns instead of dropping an unknown key silently' do
      send_with(reasoning_effort: 'high')

      expect(logger).to have_received(:warn).with(/Skipping generationConfig param :reasoning_effort/)
    end

    it 'keeps sending the request when a key cannot be mapped' do
      send_with(temperature: 0.5, reasoning_effort: 'high')

      expect(mock_gemini_client).to have_received(:generate_content).with(
        hash_including(generationConfig: { temperature: 0.5 })
      )
    end

    it 'warns about an unknown key inside thinking_config and keeps the known ones' do
      send_with(thinking_config: { thinking_level: 'minimal', mystery: 1 })

      expect(logger).to have_received(:warn).with(/Skipping thinkingConfig param :mystery/)
      expect(mock_gemini_client).to have_received(:generate_content).with(
        hash_including(generationConfig: { thinkingConfig: { thinkingLevel: 'minimal' } })
      )
    end

    it 'warns when thinking_config is not a hash' do
      send_with(thinking_config: 'minimal')

      expect(logger).to have_received(:warn).with(/expected a Hash, got String/)
    end

    it 'does not warn about supported params' do
      send_with(temperature: 0.5, thinking_level: 'minimal')

      expect(logger).not_to have_received(:warn)
    end

    it 'stays silent when no logger is configured' do
      LlmConductor.configuration.logger = nil

      expect { send_with(reasoning_effort: 'high') }.not_to raise_error
    end
  end

  describe '#client (private)' do
    let(:mock_gemini_client) { double('Gemini') }

    before do
      allow(Gemini).to receive(:new).and_return(mock_gemini_client)
    end

    it 'creates Gemini client with API key and model' do
      client.send(:client)

      expect(Gemini).to have_received(:new).with(
        credentials: {
          service: 'generative-language-api',
          api_key: 'test_api_key'
        },
        options: { model: }
      )
    end

    it 'memoizes the client instance' do
      client1 = client.send(:client)
      client2 = client.send(:client)

      expect(client1).to be(client2)
      expect(Gemini).to have_received(:new).once
    end

    it 'uses configuration for API key' do
      LlmConductor.configuration.gemini_api_key = 'different_key'
      allow(Gemini).to receive(:new).and_return(mock_gemini_client)

      client.send(:client)

      expect(Gemini).to have_received(:new).with(
        credentials: {
          service: 'generative-language-api',
          api_key: 'different_key'
        },
        options: { model: }
      )
    end
  end

  describe '#client (private) — Vertex AI' do
    let(:mock_gemini_client) { double('Gemini') }

    before do
      allow(Gemini).to receive(:new).and_return(mock_gemini_client)
    end

    context 'with project_id and region (ADC auth)' do
      before do
        LlmConductor.configuration.gemini(project_id: 'my-project', region: 'us-east4')
      end

      it 'uses vertex-ai-api service with project and region' do
        client.send(:client)

        expect(Gemini).to have_received(:new).with(
          credentials: {
            service: 'vertex-ai-api',
            region: 'us-east4',
            project_id: 'my-project'
          },
          options: { model: }
        )
      end
    end

    context 'with file_path for service account' do
      before do
        LlmConductor.configuration.gemini(
          project_id: 'my-project',
          region: 'us-east4',
          file_path: '/path/to/service_account.json'
        )
      end

      it 'includes file_path in credentials' do
        client.send(:client)

        expect(Gemini).to have_received(:new).with(
          credentials: {
            service: 'vertex-ai-api',
            region: 'us-east4',
            project_id: 'my-project',
            file_path: '/path/to/service_account.json'
          },
          options: { model: }
        )
      end
    end

    context 'with file_contents for service account' do
      let(:json_contents) { '{"type":"service_account","project_id":"my-project"}' }

      before do
        LlmConductor.configuration.gemini(
          project_id: 'my-project',
          region: 'us-east4',
          file_contents: json_contents
        )
      end

      it 'includes file_contents in credentials' do
        client.send(:client)

        expect(Gemini).to have_received(:new).with(
          credentials: {
            service: 'vertex-ai-api',
            region: 'us-east4',
            project_id: 'my-project',
            file_contents: json_contents
          },
          options: { model: }
        )
      end
    end
  end

  describe 'vision support' do
    let(:mock_gemini_client) { double('Gemini') }
    let(:api_response) do
      {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => 'Vision response from Gemini' }
              ]
            }
          }
        ]
      }
    end
    let(:mock_image_data) { 'base64_encoded_image_data' }

    before do
      allow(mock_gemini_client).to receive(:generate_content).and_return(api_response)
      # Mock image fetching and encoding
      allow(client).to receive_messages(client: mock_gemini_client, fetch_and_encode_image: mock_image_data)
    end

    context 'with hash format (text and images)' do
      let(:prompt) do
        {
          text: 'What is in this image?',
          images: 'https://example.com/image.jpg'
        }
      end

      it 'formats multimodal content correctly' do
        client.send(:generate_content, prompt)

        expect(mock_gemini_client).to have_received(:generate_content) do |payload|
          parts = payload[:contents][0][:parts]
          expect(parts.length).to eq(2)
          expect(parts[0][:text]).to eq('What is in this image?')
          expect(parts[1][:inline_data][:data]).to eq(mock_image_data)
          expect(parts[1][:inline_data][:mime_type]).to eq('image/jpeg')
        end
      end

      it 'fetches and encodes the image' do
        client.send(:generate_content, prompt)
        expect(client).to have_received(:fetch_and_encode_image).with('https://example.com/image.jpg')
      end
    end

    context 'with multiple images' do
      let(:prompt) do
        {
          text: 'Compare these images',
          images: [
            'https://example.com/image1.jpg',
            'https://example.com/image2.jpg'
          ]
        }
      end

      it 'includes all images in the payload' do
        client.send(:generate_content, prompt)

        expect(mock_gemini_client).to have_received(:generate_content) do |payload|
          parts = payload[:contents][0][:parts]
          expect(parts.length).to eq(3) # 1 text + 2 images
          expect(parts[0][:text]).to eq('Compare these images')
          expect(parts[1][:inline_data][:data]).to eq(mock_image_data)
          expect(parts[2][:inline_data][:data]).to eq(mock_image_data)
        end
      end

      it 'fetches and encodes both images' do
        client.send(:generate_content, prompt)
        expect(client).to have_received(:fetch_and_encode_image).with('https://example.com/image1.jpg')
        expect(client).to have_received(:fetch_and_encode_image).with('https://example.com/image2.jpg')
      end
    end

    context 'with array format' do
      let(:prompt) do
        [
          { type: 'text', text: 'Analyze this:' },
          { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } },
          { type: 'text', text: 'What do you see?' }
        ]
      end

      it 'converts array format to Gemini parts' do
        client.send(:generate_content, prompt)

        expect(mock_gemini_client).to have_received(:generate_content) do |payload|
          parts = payload[:contents][0][:parts]
          expect(parts.length).to eq(3)
          expect(parts[0][:text]).to eq('Analyze this:')
          expect(parts[1][:inline_data][:data]).to eq(mock_image_data)
          expect(parts[2][:text]).to eq('What do you see?')
        end
      end
    end

    context 'with image hash format' do
      let(:prompt) do
        {
          text: 'Describe this image',
          images: [
            { url: 'https://example.com/image.jpg' }
          ]
        }
      end

      it 'handles image hash format' do
        client.send(:generate_content, prompt)

        expect(mock_gemini_client).to have_received(:generate_content) do |payload|
          parts = payload[:contents][0][:parts]
          expect(parts.length).to eq(2)
          expect(parts[1][:inline_data][:data]).to eq(mock_image_data)
        end
      end
    end

    context 'with webp images' do
      let(:prompt) do
        {
          text: 'What is this?',
          images: 'https://example.com/image.webp'
        }
      end

      it 'detects webp mime type correctly' do
        client.send(:generate_content, prompt)

        expect(mock_gemini_client).to have_received(:generate_content) do |payload|
          parts = payload[:contents][0][:parts]
          expect(parts[1][:inline_data][:mime_type]).to eq('image/webp')
        end
      end
    end
  end

  describe 'integration with base class' do
    let(:data) { { content: 'TestCorp is an AI company that develops innovative solutions.' } }
    let(:mock_gemini_client) { double('Gemini') }
    let(:api_response) do
      {
        'candidates' => [
          {
            'content' => {
              'parts' => [
                { 'text' => 'Gemini response' }
              ]
            }
          }
        ]
      }
    end
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2 token3]) }

    before do
      allow(Gemini).to receive(:new).and_return(mock_gemini_client)
      allow(mock_gemini_client).to receive(:generate_content).and_return(api_response)
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'generates complete response with tokens', :aggregate_failures do
      result = client.generate(data:)

      expect(result).to be_a(LlmConductor::Response)
      expect(result.output).to eq('Gemini response')
      expect(result.input_tokens).to eq(3)
      expect(result.output_tokens).to eq(3)
      expect(result.metadata[:prompt]).to include('TestCorp')
    end
  end
end
