# LLM Conductor

A powerful Ruby gem from [Ekohe](https://ekohe.com) for orchestrating multiple Language Model providers with a unified, modern interface. LLM Conductor provides seamless integration with OpenAI GPT, Anthropic Claude, Google Gemini, and Ollama with advanced prompt management, data building patterns, and comprehensive response handling.

## Features

🚀 **Multi-Provider Support** - OpenAI GPT, Anthropic Claude, Google Gemini, and Ollama with automatic vendor detection
🎯 **Unified Modern API** - Simple `LlmConductor.generate()` interface with rich Response objects  
📝 **Advanced Prompt Management** - Registrable prompt classes with inheritance and templating  
🏗️ **Data Builder Pattern** - Structured data preparation for complex LLM inputs  
⚡ **Smart Configuration** - Rails-style configuration with environment variable support  
💰 **Cost Tracking** - Automatic token counting and cost estimation  
🔧 **Extensible Architecture** - Easy to add new providers and prompt types  
🛡️ **Robust Error Handling** - Comprehensive error handling with detailed metadata  

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'llm_conductor'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install llm_conductor
```

## Quick Start

### 1. Simple Text Generation

```ruby
# Direct prompt generation - easiest way to get started
response = LlmConductor.generate(
  model: 'gpt-5-mini',
  prompt: 'Explain quantum computing in simple terms'
)

puts response.output           # The generated text
puts response.total_tokens     # Token usage
puts response.estimated_cost   # Cost in USD
```

### 2. Template-Based Generation

```ruby
# Use built-in templates with structured data
response = LlmConductor.generate(
  model: 'gpt-5-mini',
  type: :summarize_description,
  data: {
    name: 'Ekohe',
    domain_name: 'ekohe.com',
    description: 'An AI company specializing in...'
  }
)

# Response object provides rich information
if response.success?
  puts "Generated: #{response.output}"
  puts "Tokens: #{response.total_tokens}"
  puts "Cost: $#{response.estimated_cost}"
else
  puts "Error: #{response.metadata[:error]}"
end
```

## Configuration

### Rails-Style Configuration

Create `config/initializers/llm_conductor.rb` (Rails) or configure in your application:

```ruby
LlmConductor.configure do |config|
  # Default settings
  config.default_model = 'gpt-5-mini'
  config.default_vendor = :openai
  config.timeout = 30
  config.max_retries = 3
  config.retry_delay = 1.0

  # Provider configurations
  config.openai(
    api_key: ENV['OPENAI_API_KEY'],
    organization: ENV['OPENAI_ORG_ID'] # Optional
  )

  config.anthropic(
    api_key: ENV['ANTHROPIC_API_KEY']
  )

  config.gemini(
    api_key: ENV['GEMINI_API_KEY']
  )

  config.ollama(
    base_url: ENV['OLLAMA_ADDRESS'] || 'http://localhost:11434'
  )
end
```

### Environment Variables

The gem automatically detects these environment variables:

- `OPENAI_API_KEY` - OpenAI API key
- `OPENAI_ORG_ID` - OpenAI organization ID (optional)
- `ANTHROPIC_API_KEY` - Anthropic API key
- `GEMINI_API_KEY` - Google Gemini API key
- `OLLAMA_ADDRESS` - Ollama server address

## Supported Providers & Models

### OpenAI (Automatic for GPT models)
```ruby
response = LlmConductor.generate(
  model: 'gpt-5-mini',  # Auto-detects OpenAI
  prompt: 'Your prompt here'
)
```

### Anthropic Claude (Automatic for Claude models)
```ruby
response = LlmConductor.generate(
  model: 'claude-3-5-sonnet-20241022',  # Auto-detects Anthropic
  prompt: 'Your prompt here'
)

# Or explicitly specify vendor
response = LlmConductor.generate(
  model: 'claude-3-5-sonnet-20241022',
  vendor: :anthropic,
  prompt: 'Your prompt here'
)
```

**Why Choose Claude?**
- **Superior Reasoning**: Excellent for complex analysis and problem-solving
- **Code Generation**: Outstanding performance for programming tasks
- **Long Context**: Support for large documents and conversations
- **Safety**: Built with safety and helpfulness in mind
- **Cost Effective**: Competitive pricing for high-quality outputs

### Google Gemini (Automatic for Gemini models)
```ruby
response = LlmConductor.generate(
  model: 'gemini-2.5-flash',  # Auto-detects Gemini
  prompt: 'Your prompt here'
)

# Or explicitly specify vendor
response = LlmConductor.generate(
  model: 'gemini-2.5-flash',
  vendor: :gemini,
  prompt: 'Your prompt here'
)
```

**Supported Gemini Models:**
- `gemini-2.5-flash` (Latest Gemini 2.5 Flash)
- `gemini-2.5-flash` (Gemini 2.5 Flash)
- `gemini-2.0-flash` (Gemini 2.0 Flash)

**Why Choose Gemini?**
- **Multimodal**: Native support for text, images, and other modalities
- **Long Context**: Massive context windows for large documents
- **Fast Performance**: Optimized for speed and efficiency
- **Google Integration**: Seamless integration with Google services
- **Competitive Pricing**: Cost-effective for high-volume usage

### Ollama (Default for non-GPT/Claude/Gemini models)
```ruby
response = LlmConductor.generate(
  model: 'llama3.2',  # Auto-detects Ollama for non-GPT/Claude/Gemini models
  prompt: 'Your prompt here'
)
```

### Vendor Detection

The gem automatically detects the appropriate provider based on model names:

- **OpenAI**: Models starting with `gpt-` (e.g., `gpt-4`, `gpt-3.5-turbo`)
- **Anthropic**: Models starting with `claude-` (e.g., `claude-3-5-sonnet-20241022`)
- **Google Gemini**: Models starting with `gemini-` (e.g., `gemini-2.5-flash`, `gemini-2.0-flash`)
- **Ollama**: All other models (e.g., `llama3.2`, `mistral`, `codellama`)

You can also explicitly specify the vendor:

```ruby
response = LlmConductor.generate(
  model: 'llama3.2',  # Auto-detects Ollama for non-GPT models
  prompt: 'Your prompt here'
)
```

## Advanced Features

### 1. Custom Prompt Registration

Create reusable, testable prompt classes:

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

# Register the prompt
LlmConductor::PromptManager.register(:detailed_analysis, CompanyAnalysisPrompt)

# Use the registered prompt
response = LlmConductor.generate(
  model: 'gpt-5-mini',
  type: :detailed_analysis,
  data: {
    name: 'Ekohe',
    domain_name: 'ekohe.com',
    description: 'A leading AI company...'
  }
)

# Parse structured responses
analysis = response.parse_json
puts analysis
```

### 2. Data Builder Pattern

Structure complex data for LLM consumption:

```ruby
class CompanyDataBuilder < LlmConductor::DataBuilder
  def build
    {
      id: source_object.id,
      name: source_object.name,
      description: format_for_llm(source_object.description, max_length: 500),
      industry: extract_nested_data(:data, 'categories', 'primary'),
      metrics: build_metrics,
      summary: build_company_summary,
      domain_name: source_object.domain_name

    }
  end

  private

  def build_metrics
    {
      employees: format_number(source_object.employee_count),
      revenue: format_number(source_object.annual_revenue),
      growth_rate: "#{source_object.growth_rate}%"
    }
  end

  def build_company_summary
    name = safe_extract(:name, default: 'Company')
    industry = extract_nested_data(:data, 'categories', 'primary')
    "#{name} is a #{industry} company..."
  end
end

# Usage
company = Company.find(123)
data = CompanyDataBuilder.new(company).build

response = LlmConductor.generate(
  model: 'gpt-5-mini',
  type: :detailed_analysis, 
  data: data
)
```

### 3. Built-in Prompt Templates

#### Featured Links Extraction
```ruby
response = LlmConductor.generate(
  model: 'gpt-5-mini',
  type: :featured_links,
  data: {
    htmls: '<html>...</html>',
    current_url: 'https://example.com'
  }
)
```

#### HTML Summarization
```ruby
response = LlmConductor.generate(
  model: 'gpt-5-mini', 
  type: :summarize_htmls,
  data: { htmls: '<html>...</html>' }
)
```

#### Description Summarization
```ruby
response = LlmConductor.generate(
  model: 'gpt-5-mini',
  type: :summarize_description,
  data: {
    name: 'Company Name',
    description: 'Long description...',
    industries: ['Tech', 'AI']
  }
)
```

#### Custom Templates
```ruby
response = LlmConductor.generate(
  model: 'gpt-5-mini',
  type: :custom,
  data: {
    template: "Analyze this data: %{data}",
    data: "Your data here"
  }
)
```

### 4. Response Object

All methods return a rich `LlmConductor::Response` object:

```ruby
response = LlmConductor.generate(...)

# Main content
response.output           # Generated text
response.success?         # Boolean success status

# Token information
response.input_tokens     # Input tokens used
response.output_tokens    # Output tokens generated  
response.total_tokens     # Total tokens

# Cost tracking (for supported models)
response.estimated_cost   # Estimated cost in USD

# Metadata
response.model           # Model used
response.metadata        # Hash with vendor, timestamp, etc.

# Structured data parsing
response.parse_json                    # Parse as JSON
response.extract_code_block('json')    # Extract code blocks
```

### 5. Error Handling

The gem provides comprehensive error handling:

```ruby
response = LlmConductor.generate(
  model: 'gpt-5-mini',
  prompt: 'Your prompt'
)

if response.success?
  puts response.output
else
  puts "Error: #{response.metadata[:error]}"
  puts "Failed model: #{response.model}"
end

# Exception handling for critical errors
begin
  response = LlmConductor.generate(...)
rescue LlmConductor::Error => e
  puts "LLM Conductor error: #{e.message}"
rescue StandardError => e
  puts "General error: #{e.message}" 
end
```

## Extending the Gem

### Adding Custom Clients

```ruby
module LlmConductor
  module Clients
    class CustomClient < BaseClient
      private

      def generate_content(prompt)
        # Implement your provider's API call
        your_custom_api.generate(prompt)
      end
    end
  end
end
```

### Adding Prompt Types

```ruby
module LlmConductor
  module Prompts
    def prompt_custom_analysis(data)
      <<~PROMPT
        Custom analysis for: #{data[:subject]}
        Context: #{data[:context]}
        
        Please provide detailed analysis.
      PROMPT
    end
  end
end
```

## Examples

Check the `/examples` directory for comprehensive usage examples:

- `simple_usage.rb` - Basic text generation
- `prompt_registration.rb` - Custom prompt classes
- `data_builder_usage.rb` - Data structuring patterns
- `rag_usage.rb` - RAG implementation examples

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

```bash
# Install dependencies
bin/setup

# Run tests 
rake spec

# Run RuboCop
rubocop

# Interactive console
bin/console
```

## Testing

The gem includes comprehensive test coverage with unit, integration, and performance tests.

## Performance

- **Token Efficiency**: Automatic prompt optimization and token counting
- **Cost Tracking**: Real-time cost estimation for all supported models
- **Response Caching**: Built-in mechanisms to avoid redundant API calls
- **Async Support**: Ready for async/background processing

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ekohe/llm_conductor.

1. Fork the repository
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
