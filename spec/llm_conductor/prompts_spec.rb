# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmConductor::Prompts do
  let(:test_class) { Class.new { include LlmConductor::Prompts }.new }

  describe '#prompt_featured_links' do
    let(:data) do
      {
        htmls: '<html><body><a href="/about">About</a><a href="/contact">Contact</a></body></html>',
        current_url: 'https://example.com'
      }
    end

    it 'generates a prompt for extracting featured links' do
      result = test_class.prompt_featured_links(data)

      expect(result).to include('analyzing a webpage\'s HTML content to extract the most valuable links')
      expect(result).to include(data[:htmls])
      expect(result).to include(data[:current_url])
      expect(result).to include('["https://example.com/about-us", "https://example.com/products"')
    end

    it 'handles missing data gracefully' do
      result = test_class.prompt_featured_links({})

      expect(result).to include('analyzing a webpage\'s HTML content')
      expect(result).to include('<page_html>')
      expect(result).to include('<domain>')
    end
  end

  describe '#prompt_summarize_htmls' do
    let(:data) do
      { htmls: '<html><body><h1>Company Name</h1><p>We do great things</p></body></html>' }
    end

    it 'generates a prompt for HTML summarization' do
      result = test_class.prompt_summarize_htmls(data)

      expect(result).to include('Extract useful information from the webpage')
      expect(result).to include('domain, detailed description')
      expect(result).to include('founding year, country, business model')
      expect(result).to include(data[:htmls])
      expect(result).to include('"name": "AI-powered customer service"')
    end

    it 'includes JSON example format' do
      result = test_class.prompt_summarize_htmls(data)

      expect(result).to include('"domain_name": "example.com"')
      expect(result).to include('"business_model": "SaaS subscription"')
      expect(result).to include('"social_media_links"')
    end
  end

  describe '#prompt_summarize_description' do
    let(:data) do
      {
        name: 'TechCorp',
        domain_name: 'techcorp.com',
        description: 'A leading AI company',
        industries: ['Artificial Intelligence', 'Software']
      }
    end

    it 'generates a prompt for description summarization' do
      result = test_class.prompt_summarize_description(data)

      expect(result).to include('Given the company\'s name, domain, description')
      expect(result).to include('summarize the company\'s core business')
      expect(result).to include('identify the three most relevant industries')
      expect(result).to include('unique value proposition')
      expect(result).to include('primary market focus')
    end

    it 'includes company data in the prompt' do
      result = test_class.prompt_summarize_description(data)

      expect(result).to include('TechCorp')
      expect(result).to include('techcorp.com')
      expect(result).to include('A leading AI company')
      expect(result).to include('Artificial Intelligence')
      expect(result).to include('Software')
    end

    it 'handles missing data gracefully' do
      minimal_data = { name: 'TestCorp' }
      result = test_class.prompt_summarize_description(minimal_data)

      expect(result).to include('TestCorp')
      expect(result).to include('summarize the company\'s core business')
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
