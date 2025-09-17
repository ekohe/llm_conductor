# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::DataBuilder do
  # Test helper classes
  class TestDataBuilder < described_class
    def build
      {
        name: source_object.name,
        description: safe_extract(:description, default: 'No description')
      }
    end
  end

  class AdvancedDataBuilder < described_class
    def build
      {
        basic_info: build_basic_info,
        metrics: build_metrics,
        summary: build_summary(:name, :industry, :location)
      }
    end

    private

    def build_basic_info
      {
        id: source_object.id,
        name: format_for_llm(source_object.name, max_length: 50),
        industry: extract_nested_data(:data, 'industry', 'primary')
      }
    end

    def build_metrics
      {
        employees: safe_extract(:employee_count, default: 'Unknown'),
        revenue: format_number(source_object.revenue, as_currency: true),
        tags: extract_list(:tags, limit: 3, separator: ', ')
      }
    end
  end

  let(:source_data) do
    double(
      'Company',
      id: 123,
      name: 'TechCorp Inc.',
      description: 'A technology company',
      employee_count: 150,
      revenue: 5_000_000,
      industry: 'Technology',
      location: 'San Francisco',
      tags: ['AI', 'Machine Learning', 'SaaS', 'Enterprise'],
      data: {
        'industry' => {
          'primary' => 'Software',
          'secondary' => 'AI'
        }
      }
    )
  end

  let(:empty_source) do
    double(
      'EmptyCompany',
      id: nil,
      name: '',
      description: nil,
      employee_count: nil,
      revenue: nil
    )
  end

  describe '#initialize' do
    it 'stores the source object' do
      builder = described_class.new(source_data)
      expect(builder.source_object).to eq(source_data)
    end
  end

  describe '#build' do
    it 'raises NotImplementedError when not overridden' do
      builder = described_class.new(source_data)
      expect { builder.build }.to raise_error(NotImplementedError, /must implement the #build method/)
    end
  end

  describe 'subclass implementation' do
    let(:builder) { TestDataBuilder.new(source_data) }

    it 'can be subclassed and build data' do
      result = builder.build

      expect(result).to eq({
                             name: 'TechCorp Inc.',
                             description: 'A technology company'
                           })
    end

    it 'handles missing attributes with defaults' do
      builder = TestDataBuilder.new(empty_source)
      result = builder.build

      expect(result).to eq({
                             name: '',
                             description: 'No description'
                           })
    end
  end

  describe '#safe_extract' do
    let(:builder) { described_class.new(source_data) }

    context 'when attribute exists and has value' do
      it 'returns the attribute value' do
        expect(builder.send(:safe_extract, :name)).to eq('TechCorp Inc.')
      end
    end

    context 'when attribute exists but is nil' do
      it 'returns the default value' do
        allow(source_data).to receive(:name).and_return(nil)
        expect(builder.send(:safe_extract, :name, default: 'Unknown')).to eq('Unknown')
      end
    end

    context 'when attribute exists but is empty' do
      it 'returns the default value for empty strings' do
        allow(source_data).to receive(:name).and_return('')
        expect(builder.send(:safe_extract, :name, default: 'Unknown')).to eq('Unknown')
      end

      it 'returns the default value for empty arrays' do
        allow(source_data).to receive(:tags).and_return([])
        expect(builder.send(:safe_extract, :tags, default: 'None')).to eq('None')
      end
    end

    context 'when attribute does not exist' do
      it 'returns the default value' do
        expect(builder.send(:safe_extract, :nonexistent, default: 'Default')).to eq('Default')
      end
    end

    context 'when source object is nil' do
      let(:builder) { described_class.new(nil) }

      it 'returns the default value' do
        expect(builder.send(:safe_extract, :name, default: 'Unknown')).to eq('Unknown')
      end
    end
  end

  describe '#extract_nested_data' do
    let(:builder) { described_class.new(source_data) }

    context 'when nested path exists' do
      it 'returns the nested value' do
        result = builder.send(:extract_nested_data, :data, 'industry', 'primary')
        expect(result).to eq('Software')
      end
    end

    context 'when nested path partially exists' do
      it 'returns nil for missing intermediate keys' do
        result = builder.send(:extract_nested_data, :data, 'industry', 'missing')
        expect(result).to be_nil
      end
    end

    context 'when root key does not exist' do
      it 'returns nil' do
        result = builder.send(:extract_nested_data, :missing, 'key')
        expect(result).to be_nil
      end
    end

    context 'when root data is not hash-like' do
      before { allow(source_data).to receive(:data).and_return('not a hash') }

      it 'returns nil' do
        result = builder.send(:extract_nested_data, :data, 'key')
        expect(result).to be_nil
      end
    end
  end

  describe '#format_for_llm' do
    let(:builder) { described_class.new(source_data) }

    context 'with valid value' do
      it 'returns the formatted value' do
        result = builder.send(:format_for_llm, 'Hello World')
        expect(result).to eq('Hello World')
      end

      it 'applies prefix and suffix' do
        result = builder.send(:format_for_llm, 'Hello', prefix: '>>> ', suffix: ' <<<')
        expect(result).to eq('>>> Hello <<<')
      end

      it 'truncates long values when max_length specified' do
        result = builder.send(:format_for_llm, 'Very long text here', max_length: 10)
        expect(result).to eq('Very long ...')
      end
    end

    context 'with nil or empty value' do
      it 'returns default for nil' do
        result = builder.send(:format_for_llm, nil)
        expect(result).to eq('N/A')
      end

      it 'returns custom default' do
        result = builder.send(:format_for_llm, nil, default: 'Unknown')
        expect(result).to eq('Unknown')
      end

      it 'returns default for empty string' do
        result = builder.send(:format_for_llm, '')
        expect(result).to eq('N/A')
      end
    end
  end

  describe '#extract_list' do
    let(:builder) { described_class.new(source_data) }

    context 'with valid list' do
      it 'joins items with default separator' do
        result = builder.send(:extract_list, :tags)
        expect(result).to eq('AI, Machine Learning, SaaS, Enterprise')
      end

      it 'uses custom separator' do
        result = builder.send(:extract_list, :tags, separator: ' | ')
        expect(result).to eq('AI | Machine Learning | SaaS | Enterprise')
      end

      it 'limits number of items' do
        result = builder.send(:extract_list, :tags, limit: 2)
        expect(result).to eq('AI, Machine Learning')
      end
    end

    context 'with empty or missing list' do
      before { allow(source_data).to receive(:tags).and_return([]) }

      it 'returns default value' do
        result = builder.send(:extract_list, :tags)
        expect(result).to eq('None')
      end

      it 'returns custom default' do
        result = builder.send(:extract_list, :tags, default: 'No tags')
        expect(result).to eq('No tags')
      end
    end
  end

  describe '#build_summary' do
    let(:builder) { described_class.new(source_data) }

    it 'combines multiple attributes' do
      result = builder.send(:build_summary, :name, :industry, :location)
      expect(result).to eq('TechCorp Inc. | Technology | San Francisco')
    end

    it 'uses custom separator' do
      result = builder.send(:build_summary, :name, :industry, separator: ' - ')
      expect(result).to eq('TechCorp Inc. - Technology')
    end

    it 'skips empty values by default' do
      allow(source_data).to receive(:industry).and_return('')
      result = builder.send(:build_summary, :name, :industry, :location)
      expect(result).to eq('TechCorp Inc. | San Francisco')
    end

    it 'includes empty values when skip_empty is false' do
      allow(source_data).to receive(:industry).and_return('')
      result = builder.send(:build_summary, :name, :industry, :location, skip_empty: false)
      expect(result).to eq('TechCorp Inc. | N/A | San Francisco')
    end
  end

  describe '#format_number' do
    let(:builder) { described_class.new(source_data) }

    context 'with valid numbers' do
      it 'formats integers' do
        result = builder.send(:format_number, 1_234_567)
        expect(result).to eq('1,234,567')
      end

      it 'formats as currency' do
        result = builder.send(:format_number, 1_234_567, as_currency: true)
        expect(result).to eq('$1,234,567')
      end

      it 'formats with precision' do
        result = builder.send(:format_number, 1234.56789, precision: 2)
        expect(result).to eq('1,234.57')
      end

      it 'uses custom currency symbol' do
        result = builder.send(:format_number, 1000, as_currency: true, currency: '€')
        expect(result).to eq('€1,000')
      end
    end

    context 'with invalid numbers' do
      it 'handles non-numeric strings' do
        result = builder.send(:format_number, 'not a number', default: 'Invalid')
        expect(result).to eq('not a number')
      end

      it 'handles nil values' do
        result = builder.send(:format_number, nil, default: 'Unknown')
        expect(result).to eq('Unknown')
      end
    end
  end

  describe 'advanced usage' do
    let(:builder) { AdvancedDataBuilder.new(source_data) }

    it 'builds complex data structures' do
      result = builder.build

      expect(result).to include(
        basic_info: {
          id: 123,
          name: 'TechCorp Inc.',
          industry: 'Software'
        },
        metrics: {
          employees: 150,
          revenue: '$5,000,000',
          tags: 'AI, Machine Learning, SaaS'
        },
        summary: 'TechCorp Inc. | Technology | San Francisco'
      )
    end

    it 'handles missing nested data gracefully' do
      allow(source_data).to receive(:data).and_return({})
      result = builder.build

      expect(result[:basic_info][:industry]).to be_nil
    end
  end
end
