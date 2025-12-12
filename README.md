# LLM Conductor

A unified Ruby interface for multiple Language Model providers from [Ekohe](https://ekohe.com). Seamlessly integrate OpenAI GPT, Anthropic Claude, Google Gemini, Groq, Ollama, OpenRouter, and Z.ai (Zhipu AI) with a single, consistent API.

## Features

- 🚀 **Multi-Provider Support** - 7+ LLM providers with automatic vendor detection
- 🎯 **Unified API** - Same interface across all providers
- 🖼️ **Vision Support** - Send images alongside text (OpenAI, Anthropic, OpenRouter, Z.ai, Gemini)
- 🔧 **Custom Parameters** - Fine-tune with temperature, top_p, and more
- 💰 **Cost Tracking** - Automatic token counting and cost estimation
- ⚡ **Smart Configuration** - Environment variables or code-based setup

## Installation

```ruby
gem 'llm_conductor'
```

```bash
bundle install
```

## Quick Start

### 1. Simple Generation

```ruby
require 'llm_conductor'

# Set up your API key (or use ENV variables)
LlmConductor.configure do |config|
  config.openai(api_key: 'your-api-key')
end

# Generate text
response = LlmConductor.generate(
  model: 'gpt-4o-mini',
  prompt: 'Explain quantum computing in simple terms'
)

puts response.output           # Generated text
puts response.total_tokens     # Token count
puts response.estimated_cost   # Cost in USD
```

### 2. With Custom Parameters

```ruby
# Control creativity with temperature
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Write a creative story',
  vendor: :ollama,
  params: { temperature: 0.9 }
)
```

### 3. Vision/Multimodal

```ruby
# Send images with your prompt
response = LlmConductor.generate(
  model: 'gpt-4o',
  prompt: {
    text: 'What is in this image?',
    images: ['https://example.com/image.jpg']
  }
)
```

## Configuration

### Environment Variables (Easiest)

Set these environment variables and the gem auto-configures:

```bash
export OPENAI_API_KEY=your-key-here
export ANTHROPIC_API_KEY=your-key-here
export GEMINI_API_KEY=your-key-here
export GROQ_API_KEY=your-key-here
export OLLAMA_ADDRESS=http://localhost:11434  # Optional
export OPENROUTER_API_KEY=your-key-here
export ZAI_API_KEY=your-key-here
```

### Code Configuration

```ruby
LlmConductor.configure do |config|
  config.default_model = 'gpt-4o-mini'
  
  config.openai(api_key: ENV['OPENAI_API_KEY'])
  config.anthropic(api_key: ENV['ANTHROPIC_API_KEY'])
  config.gemini(api_key: ENV['GEMINI_API_KEY'])
  config.groq(api_key: ENV['GROQ_API_KEY'])
  config.ollama(base_url: 'http://localhost:11434')
  config.openrouter(api_key: ENV['OPENROUTER_API_KEY'])
  config.zai(api_key: ENV['ZAI_API_KEY'])
end
```

## Supported Providers

| Provider | Auto-Detect | Vision | Custom Params |
|----------|-------------|--------|---------------|
| OpenAI (GPT) | ✅ `gpt-*` | ✅ | 🔜 |
| Anthropic (Claude) | ✅ `claude-*` | ✅ | 🔜 |
| Google (Gemini) | ✅ `gemini-*` | ✅ | 🔜 |
| Groq | ✅ `llama/mixtral` | ❌ | 🔜 |
| Ollama | ✅ (default) | ❌ | ✅ |
| OpenRouter | 🔧 Manual | ✅ | 🔜 |
| Z.ai (Zhipu) | ✅ `glm-*` | ✅ | 🔜 |

## Common Use Cases

### Simple Q&A

```ruby
response = LlmConductor.generate(
  model: 'gpt-4o-mini',
  prompt: 'What is Ruby programming language?'
)
```

### Content Summarization

```ruby
response = LlmConductor.generate(
  model: 'claude-3-5-sonnet-20241022',
  type: :summarize_text,
  data: {
    text: 'Long article content here...',
    max_length: '100 words',
    style: 'professional'
  }
)
```

### Deterministic Output (Testing)

```ruby
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Extract email addresses from: contact@example.com',
  vendor: :ollama,
  params: { temperature: 0.0, seed: 42 }
)
```

### Vision Analysis

```ruby
response = LlmConductor.generate(
  model: 'gpt-4o',
  prompt: {
    text: 'Describe this image in detail',
    images: [
      'https://example.com/photo.jpg',
      'https://example.com/diagram.png'
    ]
  }
)
```

## Response Object

```ruby
response = LlmConductor.generate(...)

response.output           # String - Generated text
response.success?         # Boolean - Success status
response.model            # String - Model used
response.input_tokens     # Integer - Input token count
response.output_tokens    # Integer - Output token count
response.total_tokens     # Integer - Total tokens
response.estimated_cost   # Float - Cost in USD (if available)
response.metadata         # Hash - Additional info

# Parse JSON responses
response.parse_json       # Hash - Parsed JSON output

# Extract code blocks
response.extract_code_block('ruby')  # String - Code content
```

## Advanced Features

### Custom Prompt Classes

Create reusable, testable prompt templates:

```ruby
class AnalysisPrompt < LlmConductor::Prompts::BasePrompt
  def render
    <<~PROMPT
      Analyze: #{title}
      Content: #{truncate_text(content, max_length: 500)}
      
      Provide insights in JSON format.
    PROMPT
  end
end

# Register and use
LlmConductor::PromptManager.register(:analyze, AnalysisPrompt)

response = LlmConductor.generate(
  model: 'gpt-4o-mini',
  type: :analyze,
  data: { title: 'Article', content: '...' }
)
```

### Data Builder Pattern

Structure complex data for LLM consumption:

```ruby
class CompanyDataBuilder < LlmConductor::DataBuilder
  def build
    {
      name: source_object.name,
      description: format_for_llm(source_object.description, max_length: 500),
      metrics: build_metrics,
      summary: build_company_summary
    }
  end
  
  private
  
  def build_metrics
    {
      employees: format_number(source_object.employee_count),
      revenue: format_number(source_object.annual_revenue, format: :currency)
    }
  end
end
```

### Error Handling

```ruby
response = LlmConductor.generate(...)

if response.success?
  puts response.output
else
  puts "Error: #{response.metadata[:error]}"
  puts "Error class: #{response.metadata[:error_class]}"
end
```

## Documentation

- **[Custom Parameters Guide](docs/custom-parameters.md)** - Temperature, top_p, and more
- **[Vision Support Guide](docs/vision-support.md)** - Using images with LLMs
- **[Examples](examples/)** - Working code examples for all providers

## Examples

Check the [examples/](examples/) directory for comprehensive examples:

- `simple_usage.rb` - Basic text generation
- `ollama_params_usage.rb` - Custom parameters with Ollama
- `gpt_vision_usage.rb` - Vision with OpenAI
- `claude_vision_usage.rb` - Vision with Anthropic
- `gemini_vision_usage.rb` - Vision with Gemini
- `openrouter_vision_usage.rb` - Vision with OpenRouter
- `zai_usage.rb` - Using Z.ai GLM models
- `data_builder_usage.rb` - Data builder patterns
- `prompt_registration.rb` - Custom prompt classes
- `rag_usage.rb` - Retrieval-Augmented Generation

Run any example:

```bash
ruby examples/simple_usage.rb
```

## Development

```bash
# Clone and setup
git clone https://github.com/ekohe/llm-conductor.git
cd llm-conductor
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Interactive console
bin/console
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Ensure tests pass and RuboCop is clean before submitting.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).

## Credits

Developed with ❤️ by [Ekohe](https://ekohe.com) - Making AI practical, achievable, and useful.
