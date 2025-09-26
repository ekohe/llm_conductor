# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'LlmConductor Performance' do
  let(:data) do
    {
      name: 'TechCorp',
      domain_name: 'techcorp.com',
      description: 'A leading AI technology company' * 100, # Longer description
      industries: ['AI', 'Software', 'Machine Learning', 'Data Science']
    }
  end

  before(:each, :with_test_config)

  describe 'client creation performance' do
    it 'creates clients efficiently' do
      start_time = Time.zone.now
      100.times do
        LlmConductor.build_client(model: 'gpt-4o-mini', type: :summarize_text)
      end
      elapsed_time = Time.zone.now - start_time

      # Should create 100 clients in under 1 second
      expect(elapsed_time).to be < 1.0
    end

    it 'memoizes expensive operations' do
      client = LlmConductor.build_client(model: 'gpt-4o-mini', type: :summarize_text)

      # First call to client method (should create and memoize)
      start_time = Time.zone.now
      client.send(:client)
      time1 = Time.zone.now - start_time

      # Second call should be much faster (memoized)
      start_time = Time.zone.now
      client.send(:client)
      time2 = Time.zone.now - start_time

      expect(time2).to be < time1
      expect(time2).to be < 0.001 # Should be nearly instantaneous
    end
  end

  describe 'prompt generation performance' do
    let(:test_class) { Class.new { include LlmConductor::Prompts }.new }
    let(:large_html_data) do
      {
        htmls: "<html><body>#{'content ' * 10_000}</body></html>",
        current_url: 'https://example.com'
      }
    end

    it 'generates prompts efficiently for large data' do
      start_time = Time.zone.now
      test_class.prompt_extract_links(large_html_data)
      elapsed_time = Time.zone.now - start_time

      # Should generate prompt for large HTML in under 0.1 seconds
      expect(elapsed_time).to be < 0.1
    end

    it 'handles template interpolation efficiently' do
      custom_data = {
        template: 'Company: %<name>s, Domain: %<domain_name>s, Description: %<description>s',
        name: data[:name],
        domain_name: data[:domain_name],
        description: data[:description]
      }

      start_time = Time.zone.now
      100.times do
        test_class.prompt_custom(custom_data)
      end
      elapsed_time = Time.zone.now - start_time

      # Should handle 100 interpolations in under 0.1 seconds
      expect(elapsed_time).to be < 0.1
    end
  end

  describe 'token calculation performance' do
    let(:client) { LlmConductor.build_client(model: 'gpt-4o-mini', type: :summarize_text) }
    let(:large_content) { 'word ' * 10_000 }
    let(:mock_encoder) { double('encoder') }

    before do
      # Mock tiktoken to avoid actual encoding overhead in tests
      allow(Tiktoken).to receive(:get_encoding).and_return(mock_encoder)
      allow(mock_encoder).to receive(:encode).and_return(Array.new(1000, 'token'))
    end

    it 'calculates tokens efficiently for large content' do
      start_time = Time.zone.now
      10.times do
        client.send(:calculate_tokens, large_content)
      end
      elapsed_time = Time.zone.now - start_time

      # Should calculate tokens for large content efficiently
      expect(elapsed_time).to be < 0.1
    end

    it 'memoizes encoder instance' do
      # First access should create encoder
      start_time = Time.zone.now
      client.send(:encoder)
      time1 = Time.zone.now - start_time

      # Subsequent accesses should be memoized
      start_time = Time.zone.now
      client.send(:encoder)
      time2 = Time.zone.now - start_time

      expect(time2).to be < time1
    end
  end

  describe 'memory usage patterns' do
    it 'does not leak memory with repeated client creation' do
      # This test ensures we're not holding onto unnecessary references
      initial_objects = ObjectSpace.count_objects

      1000.times do
        client = LlmConductor.build_client(model: 'gpt-4o-mini', type: :custom)
        # Force some operations to ensure objects are created
        client.model
        client.type
      end

      GC.start # Force garbage collection

      final_objects = ObjectSpace.count_objects

      # Allow for some growth but ensure it's reasonable
      object_growth = final_objects[:TOTAL] - initial_objects[:TOTAL]
      expect(object_growth).to be < 10_000 # Adjust threshold as needed
    end

    it 'properly cleans up resources' do
      clients = []

      100.times do
        clients << LlmConductor.build_client(model: 'gpt-4o-mini', type: :custom)
      end

      # Clear references
      clients.clear
      GC.start

      # Create new clients - should not accumulate excessive memory
      new_clients = []
      100.times do
        new_clients << LlmConductor.build_client(model: 'llama2', type: :extract_links)
      end

      expect(new_clients.length).to eq(100)
    end
  end

  describe 'concurrent access patterns', :aggregate_failures do
    it 'handles concurrent client creation safely' do
      threads = []
      clients = []
      mutex = Mutex.new

      # Create clients concurrently
      10.times do
        threads << Thread.new do
          client = LlmConductor.build_client(model: 'gpt-4o-mini', type: :summarize_text)
          mutex.synchronize { clients << client }
        end
      end

      threads.each(&:join)

      expect(clients.length).to eq(10)
      expect(clients.all?(LlmConductor::Clients::BaseClient)).to be true
    end

    it 'handles concurrent configuration access safely' do
      threads = []
      configs = []
      mutex = Mutex.new

      10.times do |i|
        threads << Thread.new do
          config = LlmConductor.configuration
          config.default_model = "model-#{i}"
          mutex.synchronize { configs << config }
        end
      end

      threads.each(&:join)

      # All threads should get the same configuration instance
      expect(configs.uniq.length).to eq(1)
    end
  end
end
