# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::PromptManager do
  # Test prompt classes for examples
  class ValidPrompt < LlmConductor::Prompts::BasePrompt
    def render
      "Hello #{respond_to?(:name) ? name : 'World'}"
    end
  end

  class AnotherValidPrompt < LlmConductor::Prompts::BasePrompt
    def render
      "Goodbye #{name || 'World'}"
    end
  end

  class InvalidPrompt
    def render
      'This does not inherit from BasePrompt'
    end
  end

  before do
    # Clear registry before each test
    described_class.clear!
  end

  after do
    # Clean up after tests
    described_class.clear!
  end

  describe '.register' do
    it 'registers a valid prompt class' do
      expect { described_class.register(:test, ValidPrompt) }.not_to raise_error
      expect(described_class.registered?(:test)).to be true
    end

    it 'raises error for non-class objects' do
      expect do
        described_class.register(:test, 'not a class')
      end.to raise_error(LlmConductor::PromptManager::InvalidPromptClassError, 'Prompt must be a class')
    end

    it 'raises error for classes not inheriting from BasePrompt' do
      expect do
        described_class.register(:test, InvalidPrompt)
      end.to raise_error(LlmConductor::PromptManager::InvalidPromptClassError,
                         'Prompt class must inherit from BasePrompt')
    end

    it 'raises error for classes without render method' do
      prompt_without_render = Class.new(LlmConductor::Prompts::BasePrompt)

      expect do
        described_class.register(:test, prompt_without_render)
      end.to raise_error(LlmConductor::PromptManager::InvalidPromptClassError,
                         'Prompt class must implement #render method')
    end

    it 'converts type to symbol' do
      described_class.register('test', ValidPrompt)
      expect(described_class.registered?(:test)).to be true
    end
  end

  describe '.unregister' do
    it 'removes a registered prompt type' do
      described_class.register(:test, ValidPrompt)
      expect(described_class.registered?(:test)).to be true

      described_class.unregister(:test)
      expect(described_class.registered?(:test)).to be false
    end

    it 'handles unregistering non-existent types gracefully' do
      expect { described_class.unregister(:non_existent) }.not_to raise_error
    end
  end

  describe '.get' do
    it 'returns registered prompt class' do
      described_class.register(:test, ValidPrompt)
      expect(described_class.get(:test)).to eq(ValidPrompt)
    end

    it 'raises error for unregistered prompt type' do
      expect do
        described_class.get(:non_existent)
      end.to raise_error(LlmConductor::PromptManager::PromptNotFoundError,
                         'Prompt type :non_existent not found')
    end
  end

  describe '.registered?' do
    it 'returns true for registered types' do
      described_class.register(:test, ValidPrompt)
      expect(described_class.registered?(:test)).to be true
    end

    it 'returns false for unregistered types' do
      expect(described_class.registered?(:non_existent)).to be false
    end

    it 'works with string and symbol keys' do
      described_class.register('test', ValidPrompt)
      expect(described_class.registered?(:test)).to be true
      expect(described_class.registered?('test')).to be true
    end
  end

  describe '.types' do
    it 'returns empty array when no types registered' do
      expect(described_class.types).to eq([])
    end

    it 'returns array of registered type symbols' do
      described_class.register(:first, ValidPrompt)
      described_class.register(:second, AnotherValidPrompt)

      expect(described_class.types).to contain_exactly(:first, :second)
    end
  end

  describe '.clear!' do
    it 'removes all registered types' do
      described_class.register(:first, ValidPrompt)
      described_class.register(:second, AnotherValidPrompt)

      expect(described_class.types.length).to eq(2)

      described_class.clear!
      expect(described_class.types).to be_empty
    end
  end

  describe '.create' do
    before do
      described_class.register(:test, ValidPrompt)
    end

    it 'creates instance of registered prompt class' do
      prompt = described_class.create(:test)
      expect(prompt).to be_a(ValidPrompt)
    end

    it 'passes data to prompt constructor' do
      data = { name: 'John' }
      prompt = described_class.create(:test, data)
      expect(prompt.data).to eq(data)
    end

    it 'raises error for unregistered type' do
      expect do
        described_class.create(:non_existent)
      end.to raise_error(LlmConductor::PromptManager::PromptNotFoundError)
    end
  end

  describe '.render' do
    before do
      described_class.register(:test, ValidPrompt)
    end

    it 'creates and renders prompt in one step' do
      result = described_class.render(:test, { name: 'John' })
      expect(result).to eq('Hello John')
    end

    it 'handles empty data' do
      result = described_class.render(:test)
      expect(result).to eq('Hello World')
    end

    it 'raises error for unregistered type' do
      expect do
        described_class.render(:non_existent)
      end.to raise_error(LlmConductor::PromptManager::PromptNotFoundError)
    end
  end

  describe 'registry isolation' do
    it 'maintains separate registry state' do
      # Register in this test
      described_class.register(:test1, ValidPrompt)
      expect(described_class.types).to eq([:test1])

      # Registry should be isolated from other tests
      # (verified by the before/after hooks clearing registry)
    end
  end

  describe 'thread safety' do
    it 'handles concurrent registrations safely' do
      threads = []

      5.times do |i|
        threads << Thread.new do
          described_class.register(:"test#{i}", ValidPrompt)
        end
      end

      threads.each(&:join)

      expect(described_class.types.length).to eq(5)
    end
  end
end
