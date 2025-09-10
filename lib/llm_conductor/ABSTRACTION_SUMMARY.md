# Language Model Abstraction Summary

## Overview

This document summarizes the abstraction of the `app/workers/language_model` folder into a reusable gem/lib called `LlmConductor`.

## Architecture Comparison

### Before: Tightly Coupled Structure
```
app/workers/language_model/
├── client_factory.rb           # Factory for creating clients
├── clients/
│   ├── base_client.rb         # Base client with common functionality
│   ├── gpt_client.rb          # OpenAI GPT client
│   ├── ollama_client.rb       # Ollama client
│   └── openrouter_client.rb   # OpenRouter client
├── company_data_builder.rb    # Builds data for company prompts
├── company_task_worker.rb     # Sidekiq worker
└── prompts.rb                 # Hardcoded prompt methods
```

### After: Abstracted Gem Structure
```
lib/llm_conductor/
├── llm_conductor.rb        # Main entry point
├── version.rb                 # Version management
├── configuration.rb           # Centralized configuration
├── client_factory.rb          # Enhanced factory with vendor detection
├── clients/
│   ├── base_client.rb         # Enhanced base with streaming, error handling
│   ├── openai_client.rb       # OpenAI client
│   ├── ollama_client.rb       # Ollama client
│   ├── openrouter_client.rb   # OpenRouter client
│   └── anthropic_client.rb    # New: Anthropic client
├── prompt_manager.rb          # Dynamic prompt registration system
├── prompts/
│   ├── base_prompt.rb         # Base class for prompt templates
│   └── company_analysis_prompt.rb # Example prompt implementations
├── data_builder.rb            # Base class for data builders
├── data_builders/
│   └── company_data_builder.rb # Enhanced company data builder
├── response.rb                # Rich response object
├── token_calculator.rb        # Token counting and cost estimation
├── error_handler.rb           # Comprehensive error handling
├── retry_policy.rb            # Configurable retry logic
├── integrations/
│   └── rails.rb               # Rails and Sidekiq integration
├── README.md                  # Comprehensive documentation
└── MIGRATION_GUIDE.md         # Step-by-step migration guide
```

## Key Improvements

### 1. **Configuration Management**
- **Before**: Hardcoded API keys and endpoints
- **After**: Centralized configuration with environment variable support

```ruby
# Before: Scattered configuration
@client ||= OpenAI::Client.new
@client ||= Ollama.new(credentials: { address: ENV.fetch('OLLAMA_ADDRESS') })

# After: Centralized configuration
LlmConductor.configure do |config|
  config.openai(api_key: ENV['OPENAI_API_KEY'])
  config.ollama(base_url: ENV['OLLAMA_ADDRESS'])
end
```

### 2. **Prompt Management**
- **Before**: Methods in a module, hard to extend
- **After**: Registration system with template and class support

```ruby
# Before: Fixed methods
def prompt_summarize_description(data)
  "Name: #{data[:name]}"
end

# After: Flexible registration
LlmConductor::PromptManager.register(:company_analysis, CompanyAnalysisPrompt)
```

### 3. **Error Handling**
- **Before**: Basic error catching
- **After**: Comprehensive retry logic with exponential backoff

```ruby
# Before: Basic error handling
begin
  response = client.generate(prompt)
rescue StandardError => e
  Rails.logger.error e
end

# After: Smart retry with backoff
response = client.generate(data: data)  # Automatic retry on transient errors
```

### 4. **Response Processing**
- **Before**: Raw hash response
- **After**: Rich response object with utilities

```ruby
# Before: Manual parsing
output = response[:output]
tokens = calculate_tokens(output)

# After: Rich response object
response.output           # Generated text
response.total_tokens     # Automatic token counting
response.parse_json       # JSON parsing utility
response.extract_urls     # URL extraction utility
```

### 5. **Data Building**
- **Before**: Company-specific builder
- **After**: Extensible base class with helpers

```ruby
# Before: Hardcoded for companies
class CompanyDataBuilder
  def build
    { name: company.name, domain: company.domain_name }
  end
end

# After: Extensible base with helpers
class CompanyDataBuilder < LlmConductor::DataBuilder
  def build
    extract_attributes(:id, :name, :domain_name) +
    extract_nested_data(:data, 'categories', 'founded_on')
  end
end
```

## Usage Comparison

### Simple Generation
```ruby
# Before: Multiple steps
data = LanguageModel::CompanyDataBuilder.new(company).build
client = LanguageModel::ClientFactory.build(model: 'gpt-4', type: :summarize)
result = client.generate(data: data)

# After: One-liner
response = LlmConductor.generate(
  model: 'gpt-4',
  data: CompanyDataBuilder.new(company).build,
  type: :company_analysis
)
```

### Background Processing
```ruby
# Before: Custom worker
LanguageModel::CompanyTaskWorker.perform_async('gpt-4', company.id, :summarize)

# After: Inherited worker with built-in response handling
CompanyAnalysisWorker.perform_async('gpt-4', company.id, 'company_analysis')
```

### Controller Integration
```ruby
# Before: Manual client creation and error handling
def analysis
  llm_client = client(type: :summarize_htmls)
  begin
    summary = llm_client.generate(data: data)[:output]
    # manual JSON parsing...
  rescue StandardError => e
    # manual error handling...
  end
end

# After: Rails integration with helpers
class AnalysisController < ApplicationController
  include LlmConductor::Integrations::Rails

  def analysis
    response = llm_client(model: 'gpt-4', type: :web_analysis)
                 .generate(data: build_data)
    
    render json: { analysis: response.parse_json }
  rescue LlmConductor::Error => e
    render json: handle_llm_error(e)
  end
end
```

## Benefits of Abstraction

### 1. **Reusability**
- Can be used across multiple Rails projects
- Consistent interface regardless of LLM provider
- Easy to share and maintain

### 2. **Extensibility**
- Easy to add new LLM providers
- Plugin-based prompt system
- Customizable data builders

### 3. **Maintainability**
- Centralized configuration
- Comprehensive error handling
- Rich testing utilities

### 4. **Performance**
- Automatic token counting
- Cost estimation
- Smart retry policies

### 5. **Developer Experience**
- Rich response objects
- Comprehensive documentation
- Migration guide for existing code

## Migration Path

The abstraction includes a comprehensive migration guide that allows for:

1. **Gradual Migration**: Migrate one component at a time
2. **Feature Flags**: Switch between old and new implementations
3. **Rollback Support**: Keep old code during transition
4. **Testing**: Comprehensive test utilities

## Future Enhancements

The abstracted design makes it easy to add:

1. **New Providers**: Anthropic, Cohere, local models
2. **Advanced Features**: Function calling, embeddings, fine-tuning
3. **Monitoring**: Request logging, performance metrics
4. **Caching**: Response caching for repeated requests
5. **Rate Limiting**: Built-in rate limiting per provider

This abstraction transforms a project-specific language model system into a comprehensive, reusable gem that can benefit the entire Rails community while providing better structure and capabilities than the original implementation.
