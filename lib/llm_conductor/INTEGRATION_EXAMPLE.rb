# frozen_string_literal: true

# This file shows how to integrate LlmConductor into your existing Rails application

# 1. Configuration (config/initializers/llm_conductor.rb)
LlmConductor.configure do |config|
  config.default_model = 'gpt-3.5-turbo'
  config.default_vendor = :openai
  config.timeout = 30
  config.max_retries = 3
  config.retry_delay = 1.0

  # Configure providers
  config.openai(
    api_key: ENV['OPENAI_API_KEY'],
    organization: ENV['OPENAI_ORG_ID']
  )

  config.ollama(
    base_url: ENV.fetch('OLLAMA_ADDRESS', 'http://localhost:11434')
  )

  config.openrouter(
    api_key: ENV['OPENROUTER_API_KEY']
  )
end

# 2. Register existing prompts (config/initializers/llm_prompts.rb)
LlmConductor::PromptManager.register(:summarize_description, <<~TEMPLATE)
  Given the company's name, domain, description, and a list of industry-related keywords,
  please summarize the company's core business and identify the three most relevant industries.
  Highlight the company's unique value proposition, its primary market focus,
  and any distinguishing features that set it apart within the identified industries.
  Be as objective as possible.

  Name: <%= name %>
  Domain Name: <%= domain_name %>
  Industry: <%= industries %>
  Description: <%= description %>
TEMPLATE

LlmConductor::PromptManager.register(:featured_links, <<~TEMPLATE)
  You are an AI assistant tasked with analyzing a webpage's HTML content to extract the most valuable links.
  
  <page_html>
  <%= htmls %>
  </page_html>
  
  <domain>
  <%= current_url %>
  </domain>
  
  Extract the top 3 most valuable links as JSON array.
TEMPLATE

# 3. Updated Controller (app/controllers/api/web_contents_controller.rb)
module Api
  class WebContentsController < BaseController
    include LlmConductor::Integrations::Rails
    
    before_action :authenticate_by_user_uid!

    def featured_links
      data = {
        htmls: documents,
        current_url: current_url
      }

      begin
        response = llm_client(
          model: model,
          type: :featured_links,
          vendor: vendor
        ).generate(data: data)

        links = response.extract_urls.select { |url| same_host?(url) }.take(3)
        api_success({ links: links })
      rescue LlmConductor::Error => e
        api_error handle_llm_error(e, 'There is an error please try again later.')
      end
    end

    def analysis
      data = {
        htmls: documents,
        current_url: current_url
      }

      begin
        response = llm_client(
          model: model,
          type: :summarize_htmls,
          vendor: vendor
        ).generate(data: data)

        company = response.parse_json
        api_success({ company: company })
      rescue LlmConductor::Error => e
        api_error handle_llm_error(e, 'There is an error please try again later.')
      end
    end

    private

    def model
      Rails.env.development? ? 'meta-llama/llama-4-scout' : 'gpt-4.1-nano'
    end

    def vendor
      Rails.env.development? ? :openrouter : nil
    end

    def same_host?(url)
      URI.parse(url).host == URI.parse(current_url).host
    rescue StandardError
      false
    end

    def current_url
      params[:current_url]
    end

    def documents
      docs = params[:documents].compact_blank
      case docs
      when Array
        docs.map { |doc| helpers.strip_styles_from_html(doc) }
      else
        helpers.strip_styles_from_html(docs)
      end
    end
  end
end

# 4. Updated Worker (app/workers/company_analysis_worker.rb)
class CompanyAnalysisWorker < LlmConductor::Integrations::SidekiqWorker
  sidekiq_options queue: 'data_monthly', retry: false

  def perform(model, company_id, type = 'summarize_description')
    company = Company.find_by(id: company_id)
    return unless company

    # Use the new data builder
    data = CompanyDataBuilder.new(company).build
    super(model, data, type)
  end

  private

  def process_response(response)
    company_id = response.input[:id]
    
    # Log the analysis
    Rails.logger.info "[LLM] Company #{company_id} analyzed with #{response.model}: #{response.total_tokens} tokens"
    
    # You could save results to database here
    # CompanyAnalysis.create!(
    #   company_id: company_id,
    #   analysis_type: type,
    #   results: response.output,
    #   tokens_used: response.total_tokens,
    #   model_used: response.model
    # )
  end
end

# 5. Enhanced Data Builder (app/data_builders/company_data_builder.rb)
class CompanyDataBuilder < LlmConductor::DataBuilder
  def build
    return {} unless source_object

    {
      id: safe_extract(:id),
      name: safe_extract(:name),
      domain_name: safe_extract(:domain_name),
      location: safe_extract(:location),
      description: safe_extract(:description),
      **company_data_fields,
      **company_statistics_fields
    }.compact
  end

  private

  def company_data_fields
    extract_nested_data(:data, 'categories', 'founded_on', 'employee_count', 'similarweb_visits')
      .transform_keys { |key| key == 'categories' ? :industries : key.to_sym }
  end

  def company_statistics_fields
    extract_nested_data(:statistics, 'employee_counts_quarterly_growth_yoy', 'visits_3m_avg_growth_yoy')
      .transform_keys { |key| 
        case key
        when 'employee_counts_quarterly_growth_yoy'
          :employee_growth
        when 'visits_3m_avg_growth_yoy'
          :visit_growth
        else
          key.to_sym
        end
      }
  end
end

# 6. Usage Examples

# Simple usage in a service or controller
class CompanyAnalysisService
  def self.analyze_company(company)
    data = CompanyDataBuilder.new(company).build
    
    response = LlmConductor.generate(
      model: 'gpt-4',
      data: data,
      type: :summarize_description
    )
    
    {
      analysis: response.output,
      tokens_used: response.total_tokens,
      cost_estimate: response.metadata[:cost]
    }
  end
end

# Background processing
class BulkCompanyAnalysisService
  def self.analyze_companies(company_ids, model: 'gpt-3.5-turbo')
    company_ids.each do |company_id|
      CompanyAnalysisWorker.perform_async(model, company_id, 'summarize_description')
    end
    
    { queued: company_ids.length }
  end
end

# Streaming example (for real-time analysis)
class StreamingAnalysisService
  def self.stream_analysis(company, &block)
    data = CompanyDataBuilder.new(company).build
    client = LlmConductor.client(model: 'gpt-4', type: :summarize_description)
    
    client.stream(data: data) do |chunk|
      content = chunk.dig('choices', 0, 'delta', 'content')
      block.call(content) if content
    end
  end
end

# 7. Testing Examples (spec/services/company_analysis_service_spec.rb)
RSpec.describe CompanyAnalysisService do
  let(:company) { create(:company) }
  
  before do
    allow(LlmConductor).to receive(:generate).and_return(
      LlmConductor::Response.new(
        input: 'test prompt',
        output: 'Company analysis result',
        input_tokens: 50,
        output_tokens: 100,
        model: 'gpt-4'
      )
    )
  end

  it 'analyzes company successfully' do
    result = described_class.analyze_company(company)
    
    expect(result[:analysis]).to eq('Company analysis result')
    expect(result[:tokens_used]).to eq(150)
  end
end

# 8. Migration Strategy

# Phase 1: Install gem and configure
# - Add gem to Gemfile
# - Create configuration
# - Register existing prompts

# Phase 2: Update one endpoint at a time
# - Start with less critical endpoints
# - Use feature flags to switch between old and new

# Phase 3: Update workers
# - Migrate background jobs
# - Monitor performance and error rates

# Phase 4: Clean up
# - Remove old language_model directory
# - Update tests
# - Update documentation
