# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Prompts::BasePrompt do
  # Test prompt class for examples
  class TestPrompt < described_class
    def render
      "Hello #{name}, you are #{age} years old."
    end
  end

  # Another test class with more complex rendering
  class ComplexPrompt < described_class
    def render
      <<~PROMPT
        Company: #{company_name}
        Description: #{truncate_text(description, max_length: 50)}

        Features:
        #{bulleted_list(features)}

        Steps:
        #{numbered_list(steps)}
      PROMPT
    end
  end

  let(:data) do
    {
      name: 'John',
      age: 30,
      company_name: 'TechCorp',
      description: 'A very long description that should be truncated when it exceeds the maximum length limit',
      features: ['Feature 1', 'Feature 2', 'Feature 3'],
      steps: ['First step', 'Second step', 'Third step']
    }
  end

  describe '#initialize' do
    it 'stores the provided data' do
      prompt = TestPrompt.new(data)
      expect(prompt.data).to eq(data)
    end

    it 'handles nil data gracefully' do
      prompt = TestPrompt.new(nil)
      expect(prompt.data).to eq({})
    end

    it 'creates dynamic accessor methods for data keys' do
      prompt = TestPrompt.new(data)
      expect(prompt.name).to eq('John')
      expect(prompt.age).to eq(30)
    end
  end

  describe '#render' do
    it 'raises NotImplementedError in base class' do
      base_prompt = described_class.new
      expect { base_prompt.render }.to raise_error(NotImplementedError)
    end

    it 'can be overridden in subclasses' do
      prompt = TestPrompt.new(data)
      expect(prompt.render).to eq('Hello John, you are 30 years old.')
    end
  end

  describe '#to_s' do
    it 'returns the stripped rendered prompt' do
      prompt = TestPrompt.new(data)
      expect(prompt.to_s).to eq('Hello John, you are 30 years old.')
    end

    it 'strips whitespace from rendered content' do
      prompt_class = Class.new(described_class) do
        def render
          "\n  Hello World  \n"
        end
      end

      prompt = prompt_class.new
      expect(prompt.to_s).to eq('Hello World')
    end
  end

  describe '#truncate_text' do
    let(:prompt) { TestPrompt.new }

    it 'truncates text longer than max_length' do
      result = prompt.send(:truncate_text, 'This is a very long text', max_length: 10)
      expect(result).to eq('This is a ...')
    end

    it 'returns original text if shorter than max_length' do
      result = prompt.send(:truncate_text, 'Short', max_length: 10)
      expect(result).to eq('Short')
    end

    it 'handles nil input' do
      result = prompt.send(:truncate_text, nil)
      expect(result).to eq('')
    end

    it 'converts non-string input to string' do
      result = prompt.send(:truncate_text, 12_345, max_length: 3)
      expect(result).to eq('123...')
    end
  end

  describe '#numbered_list' do
    let(:prompt) { TestPrompt.new }

    it 'creates numbered list from array' do
      items = %w[First Second Third]
      result = prompt.send(:numbered_list, items)
      expect(result).to eq("1. First\n2. Second\n3. Third")
    end

    it 'handles empty array' do
      result = prompt.send(:numbered_list, [])
      expect(result).to eq('')
    end

    it 'handles nil input' do
      result = prompt.send(:numbered_list, nil)
      expect(result).to eq('')
    end
  end

  describe '#bulleted_list' do
    let(:prompt) { TestPrompt.new }

    it 'creates bulleted list from array' do
      items = %w[First Second Third]
      result = prompt.send(:bulleted_list, items)
      expect(result).to eq("• First\n• Second\n• Third")
    end

    it 'handles empty array' do
      result = prompt.send(:bulleted_list, [])
      expect(result).to eq('')
    end

    it 'handles nil input' do
      result = prompt.send(:bulleted_list, nil)
      expect(result).to eq('')
    end
  end

  describe '#data_dig' do
    let(:nested_data) do
      {
        user: {
          profile: {
            name: 'John Doe'
          }
        }
      }
    end

    let(:prompt) { TestPrompt.new(nested_data) }

    it 'safely accesses nested hash values' do
      expect(prompt.data_dig(:user, :profile, :name)).to eq('John Doe')
    end

    it 'returns nil for non-existent keys' do
      expect(prompt.data_dig(:user, :profile, :email)).to be_nil
    end
  end

  describe 'complex prompt example' do
    it 'renders complex prompt with all helper methods' do
      prompt = ComplexPrompt.new(data)
      result = prompt.render

      expect(result).to include('Company: TechCorp')
      expect(result).to include('A very long description that should be truncated w...')
      expect(result).to include('• Feature 1')
      expect(result).to include('• Feature 2')
      expect(result).to include('1. First step')
      expect(result).to include('2. Second step')
    end
  end

  describe 'dynamic method access' do
    let(:prompt) { TestPrompt.new(data) }

    it 'provides access to data via method calls' do
      expect(prompt.name).to eq('John')
      expect(prompt.company_name).to eq('TechCorp')
    end

    it 'handles string keys in data' do
      string_data = { 'name' => 'Jane', 'age' => 25 }
      prompt = TestPrompt.new(string_data)
      expect(prompt.name).to eq('Jane')
    end

    it 'raises NoMethodError for non-existent keys' do
      expect { prompt.non_existent_key }.to raise_error(NoMethodError)
    end

    it 'supports respond_to? for dynamic methods' do
      expect(prompt.respond_to?(:name)).to be true
      expect(prompt.respond_to?(:non_existent_key)).to be false
    end
  end
end
