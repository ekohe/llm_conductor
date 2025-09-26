# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Prompts do
  let(:test_class) { Class.new { include LlmConductor::Prompts }.new }

  describe '#prompt_extract_links' do
    let(:data) do
      {
        htmls: '<html><body><a href="/about">About</a><a href="/contact">Contact</a></body></html>',
        criteria: 'navigation and content links',
        max_links: 5,
        link_types: %w[navigation content]
      }
    end

    it 'generates a prompt for extracting links' do
      result = test_class.prompt_extract_links(data)

      expect(result).to include('Analyze the provided HTML content and extract links')
      expect(result).to include(data[:htmls])
      expect(result).to include('navigation and content links')
      expect(result).to include('Maximum Links: 5')
      expect(result).to include('navigation, content')
    end

    it 'handles missing data with defaults' do
      result = test_class.prompt_extract_links({})

      expect(result).to include('relevant and useful')
      expect(result).to include('Maximum Links: 10')
      expect(result).to include('navigation, content, footer')
    end

    it 'includes domain filter when provided' do
      data_with_filter = data.merge(domain_filter: 'example.com')
      result = test_class.prompt_extract_links(data_with_filter)

      expect(result).to include('Domain Filter: Only include links from domain example.com')
    end
  end

  describe '#prompt_analyze_content' do
    let(:data) do
      {
        content: 'This is some sample content to analyze',
        content_type: 'blog post',
        fields: %w[summary key_topics sentiment],
        output_format: 'json'
      }
    end

    it 'generates a prompt for content analysis' do
      result = test_class.prompt_analyze_content(data)

      expect(result).to include('Analyze the provided blog post')
      expect(result).to include('This is some sample content to analyze')
      expect(result).to include('- summary')
      expect(result).to include('- key_topics')
      expect(result).to include('- sentiment')
    end

    it 'handles default values' do
      result = test_class.prompt_analyze_content({ content: 'test' })

      expect(result).to include('webpage content')
      expect(result).to include('- summary')
      expect(result).to include('- key_points')
      expect(result).to include('- entities')
      expect(result).to include('structured text')
    end

    it 'includes JSON format when specified' do
      result = test_class.prompt_analyze_content(data)

      expect(result).to include('Output Format: JSON')
      expect(result).to include('"summary": "value or array"')
      expect(result).to include('"key_topics": "value or array"')
    end

    it 'includes additional instructions when provided' do
      data_with_instructions = data.merge(instructions: 'Focus on technical details')
      result = test_class.prompt_analyze_content(data_with_instructions)

      expect(result).to include('Additional Instructions:')
      expect(result).to include('Focus on technical details')
    end
  end

  describe '#prompt_summarize_text' do
    let(:data) do
      {
        text: 'This is a long piece of text that needs to be summarized with key points and themes.',
        max_length: '50 words',
        style: 'professional',
        focus_areas: ['main points', 'conclusions'],
        audience: 'executives',
        include_key_points: true,
        output_format: 'paragraph'
      }
    end

    it 'generates a prompt for text summarization' do
      result = test_class.prompt_summarize_text(data)

      expect(result).to include('Summarize the following text content')
      expect(result).to include('This is a long piece of text')
      expect(result).to include('Maximum Length: 50 words')
      expect(result).to include('Style: professional')
      expect(result).to include('Focus Areas: main points, conclusions')
      expect(result).to include('Target Audience: executives')
    end

    it 'handles default values' do
      result = test_class.prompt_summarize_text({ text: 'sample text' })

      expect(result).to include('Maximum Length: 200 words')
      expect(result).to include('Style: concise and informative')
    end

    it 'includes key points instruction when specified' do
      result = test_class.prompt_summarize_text(data)

      expect(result).to include('Include key points and main themes')
    end

    it 'includes format instructions' do
      result = test_class.prompt_summarize_text(data)

      expect(result).to include('Format as a single paragraph')
    end

    it 'handles bullet points format' do
      bullet_data = data.merge(output_format: 'bullet_points')
      result = test_class.prompt_summarize_text(bullet_data)

      expect(result).to include('Format as bullet points')
    end
  end

  describe '#prompt_classify_content' do
    let(:data) do
      {
        content: 'This is a technical article about machine learning algorithms',
        categories: %w[Technology Business Health Education],
        classification_type: 'article',
        include_confidence: true
      }
    end

    it 'generates a prompt for content classification' do
      result = test_class.prompt_classify_content(data)

      expect(result).to include('Classify the provided article')
      expect(result).to include('This is a technical article about machine learning')
      expect(result).to include('1. Technology')
      expect(result).to include('2. Business')
      expect(result).to include('3. Health')
      expect(result).to include('4. Education')
    end

    it 'handles default values' do
      result = test_class.prompt_classify_content({ content: 'test content' })

      expect(result).to include('content')
      expect(result).to include('Return the most appropriate category name')
    end

    it 'includes confidence scores when requested' do
      result = test_class.prompt_classify_content(data)

      expect(result).to include('JSON with category and confidence score (0-1)')
    end

    it 'includes classification criteria when provided' do
      data_with_criteria = data.merge(classification_criteria: 'Focus on primary topic and intent')
      result = test_class.prompt_classify_content(data_with_criteria)

      expect(result).to include('Classification Criteria:')
      expect(result).to include('Focus on primary topic and intent')
    end

    it 'handles multiple categories selection' do
      multi_data = data.merge(multiple_categories: true, max_categories: 2)
      result = test_class.prompt_classify_content(multi_data)

      expect(result).to include('Multiple categories may apply - select up to 2 most relevant')
    end
  end

  describe '#prompt_custom' do
    context 'with template and data' do
      let(:data) do
        {
          template: 'Analyze this company: %<name>s at %<domain>s',
          name: 'ExampleCorp',
          domain: 'example.com'
        }
      end

      it 'interpolates the template with provided data' do
        result = test_class.prompt_custom(data)

        expect(result).to eq('Analyze this company: ExampleCorp at example.com')
      end
    end

    context 'with template only' do
      let(:data) { { template: 'Simple template without interpolation' } }

      it 'returns the template as-is when no interpolation is needed' do
        result = test_class.prompt_custom(data)

        expect(result).to eq('Simple template without interpolation')
      end
    end

    context 'with missing template' do
      it 'raises an error when template is missing' do
        expect { test_class.prompt_custom({}) }.to raise_error(KeyError)
      end
    end

    context 'with missing interpolation data' do
      let(:data) { { template: 'Hello %<name>s' } }

      it 'raises an error when required interpolation data is missing' do
        expect { test_class.prompt_custom(data) }.to raise_error(KeyError)
      end
    end
  end
end
