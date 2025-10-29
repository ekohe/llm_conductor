# LLM Conductor

A powerful Ruby gem from [Ekohe](https://ekohe.com) for orchestrating multiple Language Model providers with a unified, modern interface. LLM Conductor provides seamless integration with OpenAI GPT, Anthropic Claude, Google Gemini, Groq, Ollama, OpenRouter, and Z.ai (Zhipu AI) with advanced prompt management, data building patterns, vision/multimodal support, and comprehensive response handling.

## Features

🚀 **Multi-Provider Support** - OpenAI GPT, Anthropic Claude, Google Gemini, Groq, Ollama, OpenRouter, and Z.ai with automatic vendor detection
🎯 **Unified Modern API** - Simple `LlmConductor.generate()` interface with rich Response objects  
🖼️ **Vision/Multimodal Support** - Send images alongside text prompts for vision-enabled models (OpenRouter, Z.ai GLM-4.5V)
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
# Use built-in text summarization template
response = LlmConductor.generate(
  model: 'gpt-5-mini',
  type: :summarize_text,
  data: {
    text: 'Ekohe (ee-koh-hee) means "boundless possibility." Our way is to make AI practical, achievable, and most importantly, useful for you — and we prove it every day. With almost 16 years of wins under our belt, a market-leading 24-hr design & development cycle, and 5 offices in the most vibrant cities in the world, we surf the seas of innovation. We create efficient, elegant, and scalable digital products — delivering the right interactive solutions to achieve your audience and business goals. We help you transform. We break new ground across the globe — from AI and ML automation that drives the enterprise, to innovative customer experiences and mobile apps for startups. Our special sauce is the care, curiosity, and dedication we offer to solve for your needs. We focus on your success and deliver the most impactful experiences in the most efficient manner. Our clients tell us we partner with them in a trusted and capable way, driving the right design and technical choices.',
    max_length: '20 words',
    style: 'professional and engaging',
    focus_areas: ['core business', 'expertise', 'target market'],
    audience: 'potential investors',
    include_key_points: true,
    output_format: 'paragraph'
  }
)

# Response object provides rich information
if response.success?
  puts "Generated: #{response.output}"
  puts "Tokens: #{response.total_tokens}"
  puts "Cost: $#{response.estimated_cost || 'N/A (free model)'}"
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

  config.groq(
    api_key: ENV['GROQ_API_KEY']
  )

  config.ollama(
    base_url: ENV['OLLAMA_ADDRESS'] || 'http://localhost:11434'
  )

  config.openrouter(
    api_key: ENV['OPENROUTER_API_KEY'],
    uri_base: 'https://openrouter.ai/api/v1' # Optional, this is the default
  )

  config.zai(
    api_key: ENV['ZAI_API_KEY'],
    uri_base: 'https://api.z.ai/api/paas/v4' # Optional, this is the default
  )

  # Optional: Configure custom logger
  config.logger = Logger.new($stdout)                  # Log to stdout
  config.logger = Logger.new('log/llm_conductor.log')  # Log to file
  config.logger = Rails.logger                         # Use Rails logger (in Rails apps)
end
```

### Logging Configuration

LLM Conductor supports flexible logging using Ruby's built-in Logger class. By default, when a logger is configured, it uses the DEBUG log level to provide detailed information during development.

```ruby
LlmConductor.configure do |config|
  # Option 1: Log to stdout - uses DEBUG level by default
  config.logger = Logger.new($stdout)

  # Option 2: Log to file - set appropriate level
  config.logger = Logger.new('log/llm_conductor.log')

  # Option 3: Use Rails logger (Rails apps)
  config.logger = Rails.logger

  # Option 4: Custom logger with formatting
  config.logger = Logger.new($stderr).tap do |logger|
    logger.formatter = proc { |severity, datetime, progname, msg| "#{msg}\n" }
  end
end
```

### Environment Variables

The gem automatically detects these environment variables:

- `OPENAI_API_KEY` - OpenAI API key
- `OPENAI_ORG_ID` - OpenAI organization ID (optional)
- `ANTHROPIC_API_KEY` - Anthropic API key
- `GEMINI_API_KEY` - Google Gemini API key
- `GROQ_API_KEY` - Groq API key
- `OLLAMA_ADDRESS` - Ollama server address
- `OPENROUTER_API_KEY` - OpenRouter API key
- `ZAI_API_KEY` - Z.ai (Zhipu AI) API key

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

### Groq (Automatic for Llama, Mixtral, Gemma, Qwen models)
```ruby
response = LlmConductor.generate(
  model: 'llama-3.1-70b-versatile',  # Auto-detects Groq
  prompt: 'Your prompt here'
)

# Supported Groq models
response = LlmConductor.generate(
  model: 'mixtral-8x7b-32768',  # Auto-detects Groq
  prompt: 'Your prompt here'
)

# Or explicitly specify vendor
response = LlmConductor.generate(
  model: 'qwen-2.5-72b-instruct',
  vendor: :groq,
  prompt: 'Your prompt here'
)
```

### Ollama (Default for other models)
```ruby
response = LlmConductor.generate(
  model: 'deepseek-r1',
  prompt: 'Your prompt here'
)
```

### OpenRouter (Access to Multiple Providers)
OpenRouter provides unified access to various LLM providers with automatic routing. It also supports vision/multimodal models with automatic retry logic for handling intermittent availability issues.

**Vision-capable models:**
- `nvidia/nemotron-nano-12b-v2-vl:free` - **FREE** 12B vision model (may need retries)
- `openai/gpt-4o-mini` - Fast and reliable
- `google/gemini-flash-1.5` - Fast vision processing
- `anthropic/claude-3.5-sonnet` - High quality analysis
- `openai/gpt-4o` - Best quality (higher cost)

**Note:** Free-tier models may experience intermittent 502 errors. The client includes automatic retry logic with exponential backoff (up to 5 retries) to handle these transient failures.

```ruby
# Text-only request
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: 'Your prompt here'
)

# Vision/multimodal request with single image
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: {
    text: 'What is in this image?',
    images: 'https://example.com/image.jpg'
  }
)

# Vision request with multiple images
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: {
    text: 'Compare these images',
    images: [
      'https://example.com/image1.jpg',
      'https://example.com/image2.jpg'
    ]
  }
)

# Vision request with detail level
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: {
    text: 'Describe this image in detail',
    images: [
      { url: 'https://example.com/image.jpg', detail: 'high' }
    ]
  }
)

# Advanced: Raw array format (OpenAI-compatible)
response = LlmConductor.generate(
  model: 'nvidia/nemotron-nano-12b-v2-vl:free',
  vendor: :openrouter,
  prompt: [
    { type: 'text', text: 'What is in this image?' },
    { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } }
  ]
)
```

**Reliability:** The OpenRouter client includes intelligent retry logic:
- Automatically retries on 502 errors (up to 5 attempts)
- Exponential backoff: 2s, 4s, 8s, 16s, 32s
- Transparent to your code - works seamlessly
- Enable logging to see retry attempts:

```ruby
LlmConductor.configure do |config|
  config.logger = Logger.new($stdout)
  config.logger.level = Logger::INFO
end
```

### Z.ai (Zhipu AI) - GLM Models with Vision Support
Z.ai provides access to GLM (General Language Model) series including the powerful GLM-4.5V multimodal model with 64K context window and vision capabilities.

**Text models:**
- `glm-4-plus` - Enhanced text-only model
- `glm-4` - Standard GLM-4 model

**Vision-capable models:**
- `glm-4.5v` - Latest multimodal model with 64K context ✅ **RECOMMENDED**
- `glm-4v` - Previous generation vision model

```ruby
# Text-only request with GLM-4-plus
response = LlmConductor.generate(
  model: 'glm-4-plus',
  vendor: :zai,
  prompt: 'Explain quantum computing in simple terms'
)

# Vision request with GLM-4.5V - single image
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: {
    text: 'What is in this image?',
    images: 'https://example.com/image.jpg'
  }
)

# Vision request with multiple images
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: {
    text: 'Compare these images and identify differences',
    images: [
      'https://example.com/image1.jpg',
      'https://example.com/image2.jpg'
    ]
  }
)

# Vision request with detail level
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: {
    text: 'Analyze this document in detail',
    images: [
      { url: 'https://example.com/document.jpg', detail: 'high' }
    ]
  }
)

# Base64 encoded local images
require 'base64'
image_data = Base64.strict_encode64(File.read('path/to/image.jpg'))
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: {
    text: 'What is in this image?',
    images: "data:image/jpeg;base64,#{image_data}"
  }
)
```

**GLM-4.5V Features:**
- 64K token context window
- Multimodal understanding (text + images)
- Document understanding and OCR
- Image reasoning and analysis
- Base64 image support for local files
- OpenAI-compatible API format

### Vendor Detection

The gem automatically detects the appropriate provider based on model names:

- **OpenAI**: Models starting with `gpt-` (e.g., `gpt-4`, `gpt-3.5-turbo`)
- **Anthropic**: Models starting with `claude-` (e.g., `claude-3-5-sonnet-20241022`)
- **Google Gemini**: Models starting with `gemini-` (e.g., `gemini-2.5-flash`, `gemini-2.0-flash`)
- **Z.ai**: Models starting with `glm-` (e.g., `glm-4.5v`, `glm-4-plus`, `glm-4v`)
- **Groq**: Models starting with `llama`, `mixtral`, `gemma`, or `qwen` (e.g., `llama-3.1-70b-versatile`, `mixtral-8x7b-32768`, `gemma-7b-it`, `qwen-2.5-72b-instruct`)
- **Ollama**: All other models (e.g., `llama3.2`, `mistral`, `codellama`)

You can also explicitly specify the vendor:

```ruby
response = LlmConductor.generate(
  model: 'llama-3.1-70b-versatile',
  vendor: :groq,  # Explicitly use Groq
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
- `gemini_usage.rb` - Google Gemini integration
- `groq_usage.rb` - Groq integration with various models
- `openrouter_vision_usage.rb` - OpenRouter vision/multimodal examples
- `zai_usage.rb` - Z.ai GLM-4.5V vision and text examples

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
