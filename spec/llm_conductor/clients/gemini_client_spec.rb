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
            { parts: [{ text: prompt }] }
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
