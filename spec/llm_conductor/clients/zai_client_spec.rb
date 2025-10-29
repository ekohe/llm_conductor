# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Clients::ZaiClient do
  let(:model) { 'glm-4.5v' }
  let(:type) { :analyze_content }
  let(:client) { described_class.new(model:, type:) }

  before do
    LlmConductor.configuration.zai_api_key = 'test_zai_key'
  end

  describe 'inheritance' do
    it 'inherits from BaseClient' do
      expect(client).to be_a(LlmConductor::Clients::BaseClient)
    end
  end

  describe '#generate_content (private)' do
    let(:prompt) { 'Test prompt for Z.ai' }
    let(:mock_http_client) { double('Faraday::Connection') }
    let(:mock_request) { double('Faraday::Request', :body= => nil) }
    let(:mock_response) { double('Faraday::Response', body: api_response_json) }
    let(:api_response_json) do
      {
        'choices' => [
          {
            'message' => {
              'content' => 'Generated response from Z.ai GLM model'
            }
          }
        ]
      }.to_json
    end

    before do
      allow(client).to receive(:http_client).and_return(mock_http_client)
      allow(mock_http_client).to receive(:post).and_yield(mock_request).and_return(mock_response)
    end

    it 'calls Z.ai chat API with correct parameters' do
      client.send(:generate_content, prompt)

      expect(mock_http_client).to have_received(:post).with('chat/completions')
    end

    it 'extracts and returns the content from API response' do
      result = client.send(:generate_content, prompt)

      expect(result).to eq('Generated response from Z.ai GLM model')
    end
  end

  describe '#format_content (private)' do
    context 'with string prompt' do
      it 'returns the string as is' do
        result = client.send(:format_content, 'Simple text prompt')
        expect(result).to eq('Simple text prompt')
      end
    end

    context 'with array prompt' do
      it 'returns the array as is (pre-formatted)' do
        content = [
          { type: 'text', text: 'What is this?' },
          { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } }
        ]
        result = client.send(:format_content, content)
        expect(result).to eq(content)
      end
    end

    context 'with hash prompt' do
      it 'formats hash with text and single image' do
        prompt_hash = {
          text: 'What is in this image?',
          images: 'https://example.com/image.jpg'
        }
        result = client.send(:format_content, prompt_hash)

        expect(result).to eq([
                               { type: 'text', text: 'What is in this image?' },
                               { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } }
                             ])
      end

      it 'formats hash with text and multiple images' do
        prompt_hash = {
          text: 'Compare these images',
          images: ['https://example.com/img1.jpg', 'https://example.com/img2.jpg']
        }
        result = client.send(:format_content, prompt_hash)

        expect(result).to eq([
                               { type: 'text', text: 'Compare these images' },
                               { type: 'image_url', image_url: { url: 'https://example.com/img1.jpg' } },
                               { type: 'image_url', image_url: { url: 'https://example.com/img2.jpg' } }
                             ])
      end

      it 'works with string keys' do
        prompt_hash = {
          'text' => 'What is in this image?',
          'images' => 'https://example.com/image.jpg'
        }
        result = client.send(:format_content, prompt_hash)

        expect(result).to eq([
                               { type: 'text', text: 'What is in this image?' },
                               { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } }
                             ])
      end
    end
  end

  describe '#format_image_part (private)' do
    it 'formats string URL' do
      result = client.send(:format_image_part, 'https://example.com/image.jpg')
      expect(result).to eq({
                             type: 'image_url',
                             image_url: { url: 'https://example.com/image.jpg' }
                           })
    end

    it 'formats hash with URL and detail' do
      result = client.send(:format_image_part, {
                             url: 'https://example.com/image.jpg',
                             detail: 'high'
                           })
      expect(result).to eq({
                             type: 'image_url',
                             image_url: {
                               url: 'https://example.com/image.jpg',
                               detail: 'high'
                             }
                           })
    end

    it 'works with string keys' do
      result = client.send(:format_image_part, {
                             'url' => 'https://example.com/image.jpg',
                             'detail' => 'low'
                           })
      expect(result).to eq({
                             type: 'image_url',
                             image_url: {
                               url: 'https://example.com/image.jpg',
                               detail: 'low'
                             }
                           })
    end

    it 'handles base64 encoded images' do
      base64_image = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD'
      result = client.send(:format_image_part, base64_image)
      expect(result).to eq({
                             type: 'image_url',
                             image_url: { url: base64_image }
                           })
    end
  end

  describe '#http_client (private)' do
    let(:mock_faraday) { double('Faraday::Connection') }

    before do
      allow(Faraday).to receive(:new).and_return(mock_faraday)
    end

    it 'creates Faraday client with Z.ai configuration' do
      client.send(:http_client)

      expect(Faraday).to have_received(:new).with(url: 'https://api.z.ai/api/paas/v4')
    end

    it 'memoizes the client instance' do
      allow(Faraday).to receive(:new).and_return(mock_faraday)

      client1 = client.send(:http_client)
      client2 = client.send(:http_client)

      expect(client1).to be(client2)
      expect(Faraday).to have_received(:new).once
    end

    it 'uses configuration for Z.ai API key' do
      LlmConductor.configuration.zai_api_key = 'different_zai_key'
      allow(Faraday).to receive(:new).and_return(mock_faraday)

      client.send(:http_client)

      expect(Faraday).to have_received(:new).with(url: 'https://api.z.ai/api/paas/v4')
    end

    it 'allows custom URI base to be configured' do
      LlmConductor.configuration.zai(
        api_key: 'test_key',
        uri_base: 'https://custom.zai.endpoint/v4'
      )
      allow(Faraday).to receive(:new).and_return(mock_faraday)

      client.send(:http_client)

      expect(Faraday).to have_received(:new).with(url: 'https://custom.zai.endpoint/v4')
    end
  end

  describe 'integration with base class' do
    let(:data) do
      { content: '<html><body><h1>AI Company</h1><p>Leading AI solutions</p></body></html>' }
    end
    let(:mock_http_client) { double('Faraday::Connection') }
    let(:mock_request) { double('Faraday::Request', :body= => nil) }
    let(:mock_response) { double('Faraday::Response', body: api_response_json) }
    let(:api_response_json) do
      {
        'choices' => [
          { 'message' => { 'content' => '{"name": "AI Company", "description": "Leading AI solutions"}' } }
        ]
      }.to_json
    end
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2 token3 token4]) }

    before do
      allow(Faraday).to receive(:new).and_return(mock_http_client)
      allow(mock_http_client).to receive(:post).and_yield(mock_request).and_return(mock_response)
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'generates complete response for content analysis', :aggregate_failures do
      result = client.generate(data:)

      expect(result).to be_a(LlmConductor::Response)
      expect(result.output).to eq('{"name": "AI Company", "description": "Leading AI solutions"}')
      expect(result.input_tokens).to eq(4)
      expect(result.output_tokens).to eq(4)
      expect(result.metadata[:prompt]).to include('Analyze the provided webpage content and extract')
    end
  end

  describe 'multimodal/vision support' do
    let(:mock_http_client) { double('Faraday::Connection') }
    let(:mock_request) { double('Faraday::Request', :body= => nil) }
    let(:mock_response) { double('Faraday::Response', body: vision_api_response_json) }
    let(:vision_api_response_json) do
      {
        'choices' => [
          { 'message' => { 'content' => 'This image shows a nature boardwalk with green grass and blue sky' } }
        ]
      }.to_json
    end

    before do
      allow(Faraday).to receive(:new).and_return(mock_http_client)
      allow(mock_http_client).to receive(:post).and_yield(mock_request).and_return(mock_response)
    end

    it 'supports vision requests with hash format' do
      prompt_hash = {
        text: 'What is in this image?',
        images: 'https://example.com/image.jpg'
      }

      result = client.send(:generate_content, prompt_hash)

      expect(mock_http_client).to have_received(:post).with('chat/completions')
      expect(result).to eq('This image shows a nature boardwalk with green grass and blue sky')
    end

    it 'supports vision requests with multiple images' do
      prompt_hash = {
        text: 'Compare these images',
        images: ['https://example.com/img1.jpg', 'https://example.com/img2.jpg']
      }

      result = client.send(:generate_content, prompt_hash)

      expect(mock_http_client).to have_received(:post).with('chat/completions')
      expect(result).to eq('This image shows a nature boardwalk with green grass and blue sky')
    end

    it 'maintains backward compatibility with simple string prompts' do
      simple_prompt = 'What is the capital of France?'

      result = client.send(:generate_content, simple_prompt)

      expect(mock_http_client).to have_received(:post).with('chat/completions')
      expect(result).to eq('This image shows a nature boardwalk with green grass and blue sky')
    end

    it 'supports GLM-4.5V with high detail images' do
      prompt_hash = {
        text: 'Analyze this document in detail',
        images: [
          {
            url: 'https://example.com/document.jpg',
            detail: 'high'
          }
        ]
      }

      result = client.send(:generate_content, prompt_hash)

      expect(mock_http_client).to have_received(:post).with('chat/completions')
      expect(result).to eq('This image shows a nature boardwalk with green grass and blue sky')
    end
  end

  describe '#calculate_tokens (private)' do
    let(:mock_encoder) { double('encoder', encode: %w[token1 token2 token3 token4]) }

    before do
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
    end

    it 'calculates tokens for string content' do
      result = client.send(:calculate_tokens, 'Simple text')
      expect(result).to eq(4)
    end

    it 'calculates tokens for hash content with text' do
      result = client.send(:calculate_tokens, { text: 'Simple text', images: ['url'] })
      expect(result).to eq(4)
    end

    it 'calculates tokens for array content with text parts' do
      content = [
        { type: 'text', text: 'Simple text' },
        { type: 'image_url', image_url: { url: 'https://example.com/img.jpg' } }
      ]
      result = client.send(:calculate_tokens, content)
      expect(result).to eq(4)
    end

    it 'handles empty text in hash' do
      client.send(:calculate_tokens, { images: ['url'] })
      expect(mock_encoder).to have_received(:encode).with('')
    end
  end
end
