# Migration Guide: Upgrading to LLM Conductor 2.0

This guide helps you upgrade from LLM Conductor 1.x to 2.0, which introduces significant improvements while maintaining backward compatibility.

## Overview of Changes

LLM Conductor 2.0 introduces:

- **Rich Response Objects** instead of plain hashes
- **Direct generation API** with `LlmConductor.generate()`
- **Advanced prompt registration system** for reusable prompts
- **DataBuilder pattern** for structured data preparation  
- **Enhanced configuration system** with Rails-style setup
- **Comprehensive error handling** without exceptions
- **Smart vendor detection** based on model names

## Migration Strategy

### 1. Immediate (Keep Working)

Your existing code will continue to work unchanged. All breaking changes are opt-in.

### 2. Gradual Migration

Update components one at a time using new patterns while keeping existing code functional.

### 3. Full Migration

Eventually adopt all new patterns for the best developer experience.

## Breaking Changes & Solutions

### Response Objects vs Hashes

**Old Code (1.x):**
```ruby
result = LlmConductor.generate(
  model: 'gpt-4o-mini',
  type: :summarize_description,
  data: data
)

output = result[:output]
tokens = result[:input_tokens]
```

**New Code (2.0) - Recommended:**
```ruby
response = LlmConductor.generate(
  model: 'gpt-4o-mini', 
  type: :summarize_description,
  data: data
)

output = response.output
tokens = response.input_tokens
```

**Migration Strategy:**
```ruby
# Transitional approach - works with both versions
result = LlmConductor.generate(...)

# Handle both hash and Response object
output = result.respond_to?(:output) ? result.output : result[:output]
tokens = result.respond_to?(:input_tokens) ? result.input_tokens : result[:input_tokens]

# Or use a helper method
def extract_output(result)
  result.respond_to?(:output) ? result.output : result[:output]
end
```

### Error Handling Changes

**Old Code (1.x):**
```ruby
begin
  result = LlmConductor.generate(...)
  process_result(result[:output])
rescue LlmConductor::Error => e
  handle_error(e.message)
rescue StandardError => e
  handle_general_error(e.message)
end
```

**New Code (2.0) - Recommended:**
```ruby
response = LlmConductor.generate(...)

if response.success?
  process_result(response.output)
else
  handle_error(response.metadata[:error])
end

# Exception handling still needed for configuration errors
begin
  response = LlmConductor.generate(...)
rescue StandardError => e
  handle_configuration_error(e.message)
end
```

**Migration Strategy:**
```ruby
# Transitional error handling
def safe_generate(...)
  response = LlmConductor.generate(...)
  
  # Handle Response objects
  if response.respond_to?(:success?)
    if response.success?
      return { success: true, output: response.output }
    else
      return { success: false, error: response.metadata[:error] }
    end
  end
  
  # Handle legacy hash responses  
  { success: true, output: response[:output] }
rescue StandardError => e
  { success: false, error: e.message }
end

# Usage
result = safe_generate(model: 'gpt-4', prompt: 'test')
if result[:success]
  puts result[:output]
else
  puts "Error: #{result[:error]}"
end
```

## Feature-by-Feature Migration

### 1. Simple Text Generation

**Old:**
```ruby
client = LlmConductor.build_client(
  model: 'gpt-4o-mini',
  type: :custom
)

result = client.generate(
  data: { 
    template: '%{prompt}',
    prompt: 'Explain quantum computing'
  }
)

puts result[:output]
```

**New:**
```ruby
response = LlmConductor.generate(
  model: 'gpt-4o-mini',
  prompt: 'Explain quantum computing'
)

puts response.output
puts "Cost: $#{response.estimated_cost}"
```

### 2. Configuration System

**Old:**
```ruby
LlmConductor.configuration.openai_api_key = ENV['OPENAI_API_KEY']
LlmConductor.configuration.openrouter_api_key = ENV['OPENROUTER_API_KEY']
LlmConductor.configuration.ollama_address = 'http://localhost:11434'
```

**New (Recommended):**
```ruby
LlmConductor.configure do |config|
  config.openai(api_key: ENV['OPENAI_API_KEY'])
  config.openrouter(api_key: ENV['OPENROUTER_API_KEY'])  
  config.ollama(base_url: 'http://localhost:11434')
  
  config.default_model = 'gpt-4o-mini'
  config.timeout = 30
end
```

**Migration Strategy:**
```ruby
# Both styles work simultaneously
LlmConductor.configure do |config|
  # New style
  config.openai(api_key: ENV['OPENAI_API_KEY'])
  config.default_model = 'gpt-4o-mini'
end

# Legacy style still works
LlmConductor.configuration.openrouter_api_key = ENV['OPENROUTER_API_KEY']
```

### 3. Vendor Selection

**Old:**
```ruby
# Manual vendor specification required
client = LlmConductor.build_client(
  model: 'gpt-4',
  type: :summarize,
  vendor: :openai
)

result = client.generate(data: data)
```

**New:**
```ruby
# Automatic vendor detection
response = LlmConductor.generate(
  model: 'gpt-4',  # Auto-detects OpenAI
  type: :summarize,
  data: data
)

# Or explicit when needed
response = LlmConductor.generate(
  model: 'llama3.2',
  vendor: :openrouter,  # Override auto-detection
  prompt: 'Your prompt'
)
```

### 4. Template-Based Prompts

**Old:**
```ruby
result = LlmConductor.generate(
  model: 'gpt-4',
  type: :summarize_description,
  data: {
    name: 'TechCorp',
    description: 'Company description...'
  }
)

output = result[:output]
```

**New (Still Supported):**
```ruby
response = LlmConductor.generate(
  model: 'gpt-4',
  type: :summarize_description,
  data: {
    name: 'TechCorp', 
    description: 'Company description...'
  }
)

output = response.output
```

**Enhanced with Prompt Registration:**
```ruby
# Define reusable prompt class
class CompanyAnalysisPrompt < LlmConductor::Prompts::BasePrompt
  def render
    <<~PROMPT
      Company: #{name}
      Description: #{truncate_text(description, max_length: 500)}
      
      Please analyze this company.
    PROMPT
  end
end

# Register it
LlmConductor::PromptManager.register(:company_analysis, CompanyAnalysisPrompt)

# Use it
response = LlmConductor.generate(
  model: 'gpt-4',
  type: :company_analysis,
  data: { name: 'TechCorp', description: '...' }
)
```

## Common Migration Scenarios

### Scenario 1: Rails Controller

**Before:**
```ruby
class ApiController < ApplicationController
  def analyze_company
    begin
      client = LlmConductor.build_client(
        model: 'gpt-4',
        type: :summarize_description
      )
      
      result = client.generate(data: company_params)
      
      render json: { 
        success: true, 
        analysis: result[:output],
        tokens: result[:input_tokens] + result[:output_tokens]
      }
    rescue => e
      render json: { success: false, error: e.message }, status: 500
    end
  end
end
```

**After:**
```ruby
class ApiController < ApplicationController
  def analyze_company
    response = LlmConductor.generate(
      model: 'gpt-4',
      type: :summarize_description, 
      data: company_params
    )
    
    if response.success?
      render json: {
        success: true,
        analysis: response.output,
        tokens: response.total_tokens,
        cost: response.estimated_cost
      }
    else
      Rails.logger.error "LLM Error: #{response.metadata[:error]}"
      render json: { 
        success: false, 
        error: 'Analysis failed' 
      }, status: 500
    end
  rescue => e
    Rails.logger.error "System Error: #{e.message}"
    render json: { success: false, error: 'System error' }, status: 500
  end
end
```

### Scenario 2: Background Job

**Before:**
```ruby
class CompanyAnalysisJob < ApplicationJob
  def perform(company_id)
    company = Company.find(company_id)
    
    begin
      client = LlmConductor.build_client(
        model: 'gpt-4',
        type: :company_analysis
      )
      
      result = client.generate(data: format_company_data(company))
      
      company.update!(
        ai_analysis: result[:output],
        analysis_tokens: result[:input_tokens] + result[:output_tokens]
      )
    rescue => e
      Rails.logger.error "Analysis failed for company #{company_id}: #{e.message}"
      raise
    end
  end
end
```

**After:**
```ruby
class CompanyAnalysisJob < ApplicationJob
  def perform(company_id)
    company = Company.find(company_id)
    data = CompanyDataBuilder.new(company).build  # New DataBuilder pattern
    
    response = LlmConductor.generate(
      model: 'gpt-4',
      type: :company_analysis,
      data: data
    )
    
    if response.success?
      company.update!(
        ai_analysis: response.output,
        analysis_tokens: response.total_tokens,
        analysis_cost: response.estimated_cost,
        analyzed_at: Time.current
      )
      
      Rails.logger.info "Analysis completed for company #{company_id}"
    else
      Rails.logger.error "Analysis failed for company #{company_id}: #{response.metadata[:error]}"
      # Don't raise - job completes but analysis is marked as failed
      company.update!(analysis_failed_at: Time.current)
    end
  rescue => e
    Rails.logger.error "System error analyzing company #{company_id}: #{e.message}"
    raise  # Re-raise for job retry
  end
end
```

### Scenario 3: Service Objects

**Before:**
```ruby
class ContentAnalysisService
  def self.analyze(content)
    client = LlmConductor.build_client(
      model: 'gpt-3.5-turbo',
      type: :content_analysis
    )
    
    result = client.generate(data: { content: content })
    
    {
      success: true,
      analysis: result[:output],
      metrics: {
        input_tokens: result[:input_tokens],
        output_tokens: result[:output_tokens]
      }
    }
  rescue => e
    { success: false, error: e.message }
  end
end
```

**After:**
```ruby
class ContentAnalysisService
  class << self
    def analyze(content, options = {})
      response = generate_analysis(content, options)
      
      if response.success?
        build_success_response(response)
      else
        build_error_response(response)
      end
    rescue => e
      build_system_error_response(e)
    end
    
    private
    
    def generate_analysis(content, options)
      LlmConductor.generate(
        model: options[:model] || 'gpt-3.5-turbo',
        type: options[:prompt_type] || :content_analysis,
        data: ContentDataBuilder.new(content, options).build
      )
    end
    
    def build_success_response(response)
      {
        success: true,
        analysis: response.output,
        parsed_analysis: safe_parse_json(response),
        metrics: {
          total_tokens: response.total_tokens,
          estimated_cost: response.estimated_cost,
          model_used: response.model,
          processing_time: response.metadata[:timestamp]
        }
      }
    end
    
    def build_error_response(response)
      { 
        success: false, 
        error: 'Analysis failed',
        details: response.metadata[:error],
        model: response.model
      }
    end
    
    def build_system_error_response(error)
      { success: false, error: 'System error', details: error.message }
    end
    
    def safe_parse_json(response)
      response.parse_json
    rescue JSON::ParserError
      nil
    end
  end
end
```

## Testing Migration

### Old Test Style

```ruby
RSpec.describe CompanyAnalysisService do
  it 'analyzes company data' do
    # Mock the client
    client = double('client')
    allow(LlmConductor).to receive(:build_client).and_return(client)
    allow(client).to receive(:generate).and_return(
      output: 'Analysis result',
      input_tokens: 100,
      output_tokens: 50
    )
    
    result = CompanyAnalysisService.analyze(company_data)
    
    expect(result[:success]).to be true
    expect(result[:analysis]).to eq('Analysis result')
  end
end
```

### New Test Style

```ruby
RSpec.describe CompanyAnalysisService do
  it 'analyzes company data' do
    # Mock the response object
    response = instance_double(
      LlmConductor::Response,
      success?: true,
      output: 'Analysis result',
      total_tokens: 150,
      estimated_cost: 0.0045,
      model: 'gpt-3.5-turbo',
      metadata: { timestamp: Time.current.iso8601 }
    )
    
    allow(LlmConductor).to receive(:generate).and_return(response)
    
    result = CompanyAnalysisService.analyze(company_data)
    
    expect(result[:success]).to be true
    expect(result[:analysis]).to eq('Analysis result')
    expect(result[:metrics][:total_tokens]).to eq(150)
    expect(result[:metrics][:estimated_cost]).to eq(0.0045)
  end
  
  it 'handles LLM failures gracefully' do
    response = instance_double(
      LlmConductor::Response,
      success?: false,
      model: 'gpt-3.5-turbo',
      metadata: { error: 'API rate limit exceeded' }
    )
    
    allow(LlmConductor).to receive(:generate).and_return(response)
    
    result = CompanyAnalysisService.analyze(company_data)
    
    expect(result[:success]).to be false
    expect(result[:error]).to eq('Analysis failed')
    expect(result[:details]).to eq('API rate limit exceeded')
  end
end
```

## Advanced Migration: Custom Prompts

### Before (Built-in Templates Only)

```ruby
# Limited to built-in prompt types
result = LlmConductor.generate(
  model: 'gpt-4',
  type: :custom,
  data: {
    template: "Analyze this company: %{name}",
    name: company.name
  }
)
```

### After (Custom Prompt Classes)

```ruby
# Define reusable, testable prompt classes
class DetailedCompanyAnalysisPrompt < LlmConductor::Prompts::BasePrompt
  def render
    <<~PROMPT
      #{company_header}
      
      #{business_context}
      
      Please provide:
      #{analysis_requirements}
      
      Format as JSON with the specified structure.
    PROMPT
  end
  
  private
  
  def company_header
    <<~HEADER
      Company: #{name}
      Industry: #{industry || 'Unknown'}
      #{location_info}
    HEADER
  end
  
  def business_context
    context = ["Description: #{truncate_text(description, max_length: 400)}"]
    context << "Founded: #{founded_year}" if founded_year
    context << "Employees: #{employee_count}" if employee_count
    context.join("\n")
  end
  
  def analysis_requirements
    numbered_list([
      "Business model and revenue streams",
      "Competitive positioning and advantages", 
      "Growth potential and market opportunity",
      "Key risks and challenges"
    ])
  end
  
  def location_info
    return "" unless city || country
    "Location: #{[city, country].compact.join(', ')}"
  end
end

# Register and use
LlmConductor::PromptManager.register(:detailed_company_analysis, DetailedCompanyAnalysisPrompt)

response = LlmConductor.generate(
  model: 'gpt-4',
  type: :detailed_company_analysis,
  data: company_data
)

analysis = response.parse_json
```

## Migration Timeline Recommendation

### Week 1-2: Setup and Testing
1. Update gem to 2.0
2. Run existing tests to confirm backward compatibility
3. Update development environment configuration to new style
4. Start using Response objects in new code

### Week 3-4: Gradual Adoption  
1. Update error handling patterns in new features
2. Migrate critical services one at a time
3. Add new prompt classes for complex use cases
4. Update background jobs to use new patterns

### Week 5-6: Comprehensive Migration
1. Update all remaining services and controllers
2. Migrate all test files to new patterns
3. Replace all legacy configuration
4. Add DataBuilder classes for complex data transformation

### Week 7-8: Optimization and Cleanup
1. Remove transitional compatibility code
2. Optimize prompt classes and data builders
3. Add comprehensive error handling and logging
4. Performance testing and monitoring setup

## Troubleshooting Common Issues

### Issue: Tests Failing After Upgrade

**Problem:** Tests expecting hash responses fail with Response objects.

**Solution:**
```ruby
# Update test expectations
# Old
expect(result[:output]).to eq('expected')

# New  
expect(result.output).to eq('expected')

# Or use transitional helper
def get_output(result)
  result.respond_to?(:output) ? result.output : result[:output]  
end

expect(get_output(result)).to eq('expected')
```

### Issue: Error Handling Not Working

**Problem:** Exceptions no longer raised for LLM failures.

**Solution:**
```ruby
# Old pattern
begin
  result = LlmConductor.generate(...)
  # Process result
rescue LlmConductor::Error => e
  # Handle error
end

# New pattern
response = LlmConductor.generate(...)
if response.success?
  # Process response.output
else
  # Handle response.metadata[:error]
end
```

### Issue: Configuration Not Loading

**Problem:** Environment variables not being picked up.

**Solution:**
```ruby
# Ensure proper configuration order
LlmConductor.configure do |config|
  # Set API keys first
  config.openai(api_key: ENV['OPENAI_API_KEY'])
  
  # Then set defaults
  config.default_model = 'gpt-4o-mini'
end

# Verify configuration
openai_config = LlmConductor.configuration.provider_config(:openai)
puts "API key configured: #{!openai_config[:api_key].nil?}"
```

### Issue: Vendor Auto-Detection Wrong

**Problem:** Wrong provider being selected automatically.

**Solution:**
```ruby
# Override auto-detection explicitly
response = LlmConductor.generate(
  model: 'gpt-4',
  vendor: :openrouter,  # Force specific vendor
  prompt: 'Your prompt'
)

# Or configure default vendor
LlmConductor.configure do |config|
  config.default_vendor = :ollama  # Change default
end
```

## Getting Help

- **Documentation**: Check the updated README.md and individual guide files
- **Examples**: Look at `/examples` directory for complete working examples  
- **Tests**: Examine the test suite in `/spec` for usage patterns
- **Issues**: Report problems on the GitHub repository

The migration to 2.0 provides significant benefits in reliability, maintainability, and developer experience. Take it step by step, and you'll end up with much more robust LLM integration code.
