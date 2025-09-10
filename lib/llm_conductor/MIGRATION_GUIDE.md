# Migration Guide: From LanguageModel Workers to RailsLlmClient

This guide will help you migrate your existing `app/workers/language_model` code to use the new `RailsLlmClient` gem.

## Overview of Changes

The new gem provides:
- Better separation of concerns
- More flexible configuration
- Improved error handling
- Support for multiple providers
- Better testing capabilities
- Cleaner API design

## Step-by-Step Migration

### 1. Install and Configure the Gem

Add to your `Gemfile`:
```ruby
gem 'llm_conductor', path: 'lib/llm_conductor' # or from rubygems when published
```

Create configuration file:
```ruby
# config/initializers/llm_conductor.rb
RailsLlmClient.configure do |config|
  config.default_model = 'gpt-3.5-turbo'
  config.timeout = 30
  config.max_retries = 3

  config.openai(api_key: ENV['OPENAI_API_KEY'])
  config.ollama(base_url: ENV.fetch('OLLAMA_ADDRESS', 'http://localhost:11434'))
  config.openrouter(api_key: ENV['OPENROUTER_API_KEY'])
end
```

### 2. Migrate Prompt Definitions

**Before** (`app/workers/language_model/prompts.rb`):
```ruby
module LanguageModel
  module Prompts
    def prompt_summarize_description(data)
      <<~PROMPT
        Given the company's name, domain, description...
        Name: #{data[:name]}
        Domain Name: #{data[:domain_name]}
        Description: #{data[:description]}
      PROMPT
    end

    def prompt_featured_links(data)
      # ... prompt content
    end
  end
end
```

**After** - Create prompt classes:
```ruby
# app/llm_prompts/company_analysis_prompt.rb
class CompanyAnalysisPrompt < RailsLlmClient::Prompts::BasePrompt
  def render
    <<~PROMPT
      Given the company's name, domain, description...
      Name: #{name}
      Domain Name: #{domain_name}
      Description: #{truncate_text(description, max_length: 2000)}
    PROMPT
  end
end

# app/llm_prompts/featured_links_prompt.rb
class FeaturedLinksPrompt < RailsLlmClient::Prompts::BasePrompt
  def render
    # ... prompt content using helper methods
  end
end
```

Register prompts in an initializer:
```ruby
# config/initializers/llm_prompts.rb
RailsLlmClient::PromptManager.register(:summarize_description, CompanyAnalysisPrompt)
RailsLlmClient::PromptManager.register(:featured_links, FeaturedLinksPrompt)
```

### 3. Migrate Data Builders

**Before** (`app/workers/language_model/company_data_builder.rb`):
```ruby
module LanguageModel
  class CompanyDataBuilder
    def initialize(company)
      @company = company
    end

    def build
      {
        id: company.id,
        name: company.name,
        # ... other fields
      }
    end
  end
end
```

**After**:
```ruby
# app/data_builders/company_data_builder.rb
class CompanyDataBuilder < RailsLlmClient::DataBuilder
  def build
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
  end

  def company_statistics_fields
    extract_nested_data(:statistics, 'employee_counts_quarterly_growth_yoy', 'visits_3m_avg_growth_yoy')
  end
end
```

### 4. Migrate Workers

**Before** (`app/workers/language_model/company_task_worker.rb`):
```ruby
module LanguageModel
  class CompanyTaskWorker
    include Sidekiq::Worker

    def perform(model, company_id, type = :summarize_description)
      company = Company.find_by(id: company_id)
      return unless company

      data = CompanyDataBuilder.new(company).build
      client = ClientFactory.build(model:, type:)

      client.generate(data:)
    end
  end
end
```

**After**:
```ruby
# app/workers/company_analysis_worker.rb
class CompanyAnalysisWorker < RailsLlmClient::Integrations::SidekiqWorker
  sidekiq_options queue: 'data_monthly', retry: false

  def perform(model, company_id, analysis_type = 'summarize_description')
    company = Company.find_by(id: company_id)
    return unless company

    data = CompanyDataBuilder.new(company).build
    super(model, data, analysis_type)
  end

  private

  def process_response(response)
    # Handle the response - save to database, trigger callbacks, etc.
    company_id = response.input[:id]
    
    # Example: Save analysis results
    CompanyAnalysis.create!(
      company_id: company_id,
      analysis_type: type,
      results: response.parse_json || response.output,
      tokens_used: response.total_tokens,
      model_used: response.model
    )
  end
end
```

### 5. Update Controllers

**Before** (`app/controllers/api/web_contents_controller.rb`):
```ruby
def analysis
  llm_client = client type: :summarize_htmls
  data = { htmls: documents }

  begin
    summary = llm_client.generate(data:)[:output]
    company = JSON.parse summary[summary.index('{')..summary.rindex('}')]
    api_success({ company: })
  rescue StandardError => e
    # error handling
  end
end

private

def client(type:)
  if Rails.env.development?
    LanguageModel::ClientFactory.build(model: model, type:, vendor: :openrouter)
  else
    LanguageModel::ClientFactory.build(model: model, type:)
  end
end
```

**After**:
```ruby
# app/controllers/api/web_contents_controller.rb
class Api::WebContentsController < BaseController
  include RailsLlmClient::Integrations::Rails

  def analysis
    data = WebContentDataBuilder.new(
      documents: documents,
      current_url: current_url
    ).build

    begin
      response = llm_client(
        model: model,
        type: :summarize_htmls,
        vendor: vendor
      ).generate(data: data)

      company = response.parse_json
      api_success({ company: company })
    rescue RailsLlmClient::Error => e
      api_error handle_llm_error(e)
    end
  end

  private

  def model
    Rails.env.development? ? 'meta-llama/llama-4-scout' : 'gpt-4.1-nano'
  end

  def vendor
    Rails.env.development? ? :openrouter : nil
  end
end
```

### 6. Register New Prompt Types

Based on your existing prompts, register them:

```ruby
# config/initializers/llm_prompts.rb
RailsLlmClient::PromptManager.register(:summarize_htmls, WebContentAnalysisPrompt)
RailsLlmClient::PromptManager.register(:featured_links, FeaturedLinksPrompt)
RailsLlmClient::PromptManager.register(:summarize_description, CompanyAnalysisPrompt)
```

### 7. Update Job Calls

**Before**:
```ruby
LanguageModel::CompanyTaskWorker.perform_async('gpt-4', company.id, :summarize_description)
```

**After**:
```ruby
CompanyAnalysisWorker.perform_async('gpt-4', company.id, 'summarize_description')
```

### 8. Remove Old Files

After migration is complete and tested, you can remove:
- `app/workers/language_model/` directory
- Any references to `LanguageModel` module

### 9. Testing the Migration

Create tests to ensure the migration works:

```ruby
# spec/workers/company_analysis_worker_spec.rb
RSpec.describe CompanyAnalysisWorker do
  let(:company) { create(:company) }
  
  before do
    allow(RailsLlmClient).to receive(:generate).and_return(
      RailsLlmClient::Response.new(
        input: 'test',
        output: '{"analysis": "test"}',
        input_tokens: 10,
        output_tokens: 20
      )
    )
  end

  it 'processes company analysis' do
    expect {
      described_class.new.perform('gpt-4', company.id, 'summarize_description')
    }.to change(CompanyAnalysis, :count).by(1)
  end
end
```

## Benefits After Migration

1. **Better Error Handling**: Automatic retries, better error messages
2. **More Flexible**: Easy to add new providers and prompt types
3. **Better Testing**: Mock responses easily
4. **Token Tracking**: Automatic token counting and cost estimation
5. **Configuration**: Centralized configuration management
6. **Extensibility**: Easy to extend with custom clients and prompts

## Rollback Plan

If you need to rollback:
1. Keep the old `language_model` workers during migration
2. Use feature flags to switch between old and new implementations
3. Gradually migrate endpoints one by one
4. Monitor error rates and performance

## Common Issues and Solutions

### Issue: Prompt not found
```ruby
# Solution: Make sure prompts are registered
RailsLlmClient::PromptManager.register(:your_prompt_type, YourPromptClass)
```

### Issue: Provider not configured
```ruby
# Solution: Add provider configuration
RailsLlmClient.configure do |config|
  config.openai(api_key: ENV['OPENAI_API_KEY'])
end
```

### Issue: Token counting errors
```ruby
# Solution: Install tiktoken_ruby gem
gem 'tiktoken_ruby'
```

This migration should be done gradually, testing each component as you go. The new gem provides better structure and more features while maintaining compatibility with your existing workflow.
