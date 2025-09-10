# LlmConductor

A comprehensive Ruby gem for integrating multiple Language Model providers into Rails applications with a unified interface, flexible prompt management, and robust error handling.

## Features

- 🔌 **Multiple Provider Support**: OpenAI, Ollama, OpenRouter, Anthropic
- 🎯 **Unified Interface**: Same API across all providers
- 📝 **Flexible Prompts**: Template-based and class-based prompt management
- 🔄 **Smart Retry Logic**: Configurable retry policies with exponential backoff
- 📊 **Token Tracking**: Automatic token counting and cost estimation
- 🛡️ **Error Handling**: Comprehensive error handling with meaningful messages
- 🚀 **Rails Integration**: Built-in Rails and Sidekiq support
- 🔧 **Extensible**: Easy to add new providers and prompt types

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'llm_conductor'
```

And then execute:

```bash
bundle install
```

## Configuration

### Basic Configuration

```ruby
# config/initializers/llm_conductor.rb
LlmConductor.configure do |config|
  # Default settings
  config.default_model = 'gpt-3.5-turbo'
  config.default_vendor = :openai
  config.timeout = 30
  config.max_retries = 3
  config.retry_delay = 1.0

  # Configure providers
  config.openai(
    api_key: ENV['OPENAI_API_KEY'],
    organization: ENV['OPENAI_ORG_ID']  # optional
  )

  config.ollama(
    base_url: ENV['OLLAMA_ADDRESS'] || 'http://localhost:11434'
  )

  config.openrouter(
    api_key: ENV['OPENROUTER_API_KEY']
  )

  config.anthropic(
    api_key: ENV['ANTHROPIC_API_KEY']
  )
end
```

### Environment Variables

```bash
OPENAI_API_KEY=your_openai_key
OPENROUTER_API_KEY=your_openrouter_key
ANTHROPIC_API_KEY=your_anthropic_key
OLLAMA_ADDRESS=http://localhost:11434
```

## Usage

### Basic Usage

```ruby
# Simple text generation
response = LlmConductor.generate(
  model: 'gpt-3.5-turbo',
  prompt: 'Explain quantum computing in simple terms'
)

puts response.output
puts "Tokens used: #{response.total_tokens}"
puts "Cost: $#{response.metadata[:cost]}" if response.metadata[:cost]
```

### Using with Data and Prompt Types

```ruby
# Register a prompt template
LlmConductor::PromptManager.register(:company_summary, <<~TEMPLATE)
  Analyze this company:
  Name: <%= name %>
  Description: <%= description %>
  Industry: <%= industry %>
  
  Provide a brief summary and key insights.
TEMPLATE

# Use with structured data
company_data = {
  name: 'TechCorp',
  description: 'AI-powered solutions for businesses',
  industry: 'Technology'
}

response = LlmConductor.generate(
  model: 'gpt-4',
  data: company_data,
  type: :company_summary
)
```

### Custom Prompt Classes

```ruby
class CompanyAnalysisPrompt < LlmConductor::Prompts::BasePrompt
  def render
    <<~PROMPT
      Company: #{name}
      Domain: #{domain_name}
      Description: #{truncate_text(description, max_length: 1000)}
      
      Please analyze this company and provide:
      1. Core business model
      2. Target market
      3. Competitive advantages
      4. Growth potential
      
      Format as JSON.
    PROMPT
  end
end

# Register the prompt class
LlmConductor::PromptManager.register(:detailed_analysis, CompanyAnalysisPrompt)

# Use it
response = LlmConductor.generate(
  model: 'gpt-4',
  data: company_data,
  type: :detailed_analysis
)

# Parse JSON response
analysis = response.parse_json
```

### Custom Data Builders

```ruby
class CompanyDataBuilder < LlmConductor::DataBuilder
  def build
    {
      id: source_object.id,
      name: source_object.name,
      domain_name: source_object.domain_name,
      description: source_object.description,
      industry: extract_nested_data(:data, 'categories'),
      metrics: build_metrics
    }
  end

  private

  def build_metrics
    {
      employees: safe_extract(:employee_count, default: 'Unknown'),
      revenue: format_for_llm(source_object.revenue),
      founded: source_object.founded_year
    }
  end
end

# Use with ActiveRecord models
company = Company.find(1)
builder = CompanyDataBuilder.new(company)
data = builder.build

response = LlmConductor.generate(
  model: 'gpt-3.5-turbo',
  data: data,
  type: :company_summary
)
```

### Rails Controller Integration

```ruby
class AnalysisController < ApplicationController
  include LlmConductor::Integrations::Rails

  def analyze_company
    company = Company.find(params[:id])
    
    begin
      response = llm_client(model: 'gpt-4', type: :company_analysis)
                   .generate(data: CompanyDataBuilder.new(company).build)
      
      render json: {
        analysis: response.parse_json,
        tokens_used: response.total_tokens,
        success: response.success?
      }
    rescue LlmConductor::Error => e
      render json: handle_llm_error(e), status: :unprocessable_entity
    end
  end

  def bulk_analysis
    company_ids = params[:company_ids]
    
    # Queue for background processing
    company_ids.each do |company_id|
      CompanyAnalysisWorker.perform_async('gpt-3.5-turbo', company_id, :company_analysis)
    end
    
    render json: { message: 'Analysis queued', job_count: company_ids.length }
  end
end
```

### Sidekiq Background Jobs

```ruby
class CompanyAnalysisWorker < LlmConductor::Integrations::SidekiqWorker
  sidekiq_options queue: 'llm_analysis', retry: 3

  def perform(model, company_id, analysis_type)
    company = Company.find(company_id)
    data = CompanyDataBuilder.new(company).build
    
    super(model, data, analysis_type)
  end

  private

  def process_response(response)
    # Save analysis results
    company_id = response.input[:id]
    analysis_data = response.parse_json
    
    CompanyAnalysis.create!(
      company_id: company_id,
      analysis_type: type,
      results: analysis_data,
      tokens_used: response.total_tokens,
      model_used: response.model
    )
  end
end
```

### Streaming Responses

```ruby
client = LlmConductor.client(model: 'gpt-3.5-turbo')

client.stream(prompt: 'Write a story about AI') do |chunk|
  print chunk['choices'][0]['delta']['content'] if chunk.dig('choices', 0, 'delta', 'content')
end
```

### Advanced Configuration

```ruby
# Per-request configuration
response = LlmConductor.generate(
  model: 'gpt-4',
  prompt: 'Analyze this data...',
  temperature: 0.2,
  max_tokens: 1000,
  top_p: 0.9
)

# Custom retry policy
client = LlmConductor.client(
  model: 'gpt-3.5-turbo',
  max_retries: 5,
  retry_delay: 2.0
)

# Provider-specific options
response = LlmConductor.generate(
  model: 'meta-llama/llama-2-70b-chat',
  vendor: :openrouter,
  prompt: 'Hello world',
  provider: { sort: 'cost' }  # OpenRouter-specific
)
```

## Error Handling

The gem provides comprehensive error handling with automatic retries for transient errors:

```ruby
begin
  response = LlmConductor.generate(
    model: 'gpt-4',
    prompt: 'Analyze this...'
  )
rescue LlmConductor::ConfigurationError => e
  # Handle configuration issues
  Rails.logger.error "LLM Configuration Error: #{e.message}"
rescue LlmConductor::ClientError => e
  # Handle API errors, timeouts, etc.
  Rails.logger.error "LLM Client Error: #{e.message}"
rescue LlmConductor::TokenLimitError => e
  # Handle token limit exceeded
  Rails.logger.error "Token limit exceeded: #{e.message}"
end
```

## Response Object

The `Response` object provides rich information about the generation:

```ruby
response = LlmConductor.generate(model: 'gpt-4', prompt: 'Hello')

response.output          # Generated text
response.input           # Original prompt
response.input_tokens    # Input token count
response.output_tokens   # Output token count
response.total_tokens    # Total tokens used
response.model           # Model used
response.vendor          # Provider used
response.success?        # Whether generation succeeded

# Convenience methods
response.parse_json      # Parse JSON from output
response.extract_urls    # Extract URLs from output
response.extract_code_blocks('ruby')  # Extract code blocks

# Convert to hash/JSON
response.to_h
response.to_json
```

## Testing

The gem provides testing utilities:

```ruby
# spec/support/llm_client_helper.rb
RSpec.configure do |config|
  config.before(:each) do
    # Mock LLM responses in tests
    allow(LlmConductor).to receive(:generate).and_return(
      LlmConductor::Response.new(
        input: 'test prompt',
        output: 'test response',
        input_tokens: 10,
        output_tokens: 20
      )
    )
  end
end
```

## Migration from Existing Code

To migrate from the existing `LanguageModel` workers:

1. **Replace the worker calls:**
```ruby
# Before
LanguageModel::CompanyTaskWorker.perform_async('gpt-4', company.id, :summarize_description)

# After
CompanyAnalysisWorker.perform_async('gpt-4', company.id, :summarize_description)
```

2. **Update prompt definitions:**
```ruby
# Before (in Prompts module)
def prompt_summarize_description(data)
  # prompt content
end

# After (register with PromptManager)
LlmConductor::PromptManager.register(:summarize_description, CompanyAnalysisPrompt)
```

3. **Update data building:**
```ruby
# Before
data = CompanyDataBuilder.new(company).build

# After
data = LlmConductor::DataBuilders::CompanyDataBuilder.new(company).build
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Add tests for your changes
4. Ensure all tests pass (`bundle exec rspec`)
5. Commit your changes (`git commit -am 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Create a Pull Request

## License

The gem is available as open source under the [MIT License](LICENSE).
