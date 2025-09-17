# LLM Conductor Configuration Guide

This guide covers the comprehensive configuration system for LLM Conductor, including provider setup, environment variables, model selection, and vendor management.

## Overview

LLM Conductor uses a Rails-style configuration system that supports:
- **Provider-specific configuration** for OpenAI, OpenRouter, and Ollama
- **Smart vendor detection** based on model names
- **Environment variable integration** for secure API key management
- **Flexible defaults** with per-request overrides
- **Backward compatibility** with legacy configuration methods

## Quick Start

### Basic Configuration

```ruby
# config/initializers/llm_conductor.rb (Rails)
# or in your application startup code
LlmConductor.configure do |config|
  # Essential provider setup
  config.openai(api_key: ENV['OPENAI_API_KEY'])
  config.openrouter(api_key: ENV['OPENROUTER_API_KEY'])
  config.ollama(base_url: ENV['OLLAMA_ADDRESS'] || 'http://localhost:11434')
  
  # Optional defaults
  config.default_model = 'gpt-4o-mini'
  config.default_vendor = :openai
end
```

### Environment Variables

Set these environment variables for automatic configuration:

```bash
# Required for OpenAI
export OPENAI_API_KEY="sk-your-openai-key"
export OPENAI_ORG_ID="org-your-org-id"  # Optional

# Required for OpenRouter
export OPENROUTER_API_KEY="sk-or-v1-your-key"

# Optional for Ollama (defaults to http://localhost:11434)
export OLLAMA_ADDRESS="http://your-ollama-server:11434"
```

## Configuration Options

### Global Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `default_model` | String | `'gpt-3.5-turbo'` | Model used when none specified |
| `default_vendor` | Symbol | `:openai` | Vendor for automatic detection fallback |
| `timeout` | Integer | `30` | Request timeout in seconds |
| `max_retries` | Integer | `3` | Maximum retry attempts for failed requests |
| `retry_delay` | Float | `1.0` | Delay between retry attempts in seconds |

```ruby
LlmConductor.configure do |config|
  config.default_model = 'gpt-4o-mini'
  config.default_vendor = :openai
  config.timeout = 60          # Longer timeout for complex queries
  config.max_retries = 5       # More retries for production
  config.retry_delay = 2.0     # Longer delay between retries
end
```

### Provider-Specific Configuration

#### OpenAI Configuration

```ruby
config.openai(
  api_key: 'sk-your-api-key',           # Required
  organization: 'org-your-org-id',      # Optional - for org-specific usage
  timeout: 30,                          # Optional - override global timeout
  max_retries: 3                        # Optional - override global retries
)
```

**Supported Models:**
- `gpt-4`, `gpt-4-turbo`, `gpt-4o`, `gpt-4o-mini`
- `gpt-3.5-turbo`, `gpt-3.5-turbo-16k`
- Any model starting with `gpt` (auto-detected)

#### OpenRouter Configuration

```ruby
config.openrouter(
  api_key: 'sk-or-v1-your-key',         # Required
  timeout: 45,                          # Optional - override global timeout
  max_retries: 2                        # Optional - override global retries  
)
```

**Popular Models:**
- `meta-llama/llama-3.2-90b-vision-instruct`
- `anthropic/claude-3.5-sonnet`
- `google/gemini-pro`
- `mistralai/mixtral-8x7b-instruct`

#### Ollama Configuration

```ruby
config.ollama(
  base_url: 'http://localhost:11434',   # Default URL
  timeout: 120,                         # Longer timeout for local processing
  max_retries: 1                        # Fewer retries for local server
)
```

**Popular Models:**
- `llama3.2`, `llama3.1`, `llama2`
- `mistral`, `mixtral`
- `codellama`, `phi3`

## Smart Vendor Detection

LLM Conductor automatically determines the appropriate vendor based on model names:

### Automatic Detection Rules

```ruby
# These models auto-detect to OpenAI
'gpt-4o-mini'     → :openai
'gpt-4'           → :openai  
'gpt-3.5-turbo'   → :openai

# Non-GPT models default to Ollama
'llama3.2'        → :ollama
'mistral'         → :ollama
'codellama'       → :ollama

# Explicit vendor needed for OpenRouter
'meta-llama/llama-3.2-90b' + vendor: :openrouter → :openrouter
```

### Override Vendor Detection

```ruby
# Force a specific vendor
response = LlmConductor.generate(
  model: 'gpt-4',
  vendor: :openrouter,  # Use OpenRouter instead of OpenAI
  prompt: 'Your prompt'
)
```

## Usage Patterns

### 1. Simple Generation with Auto-Detection

```ruby
# Uses OpenAI (auto-detected from 'gpt-4o-mini')
response = LlmConductor.generate(
  model: 'gpt-4o-mini',
  prompt: 'Explain quantum computing'
)

# Uses Ollama (auto-detected for non-GPT models)  
response = LlmConductor.generate(
  model: 'llama3.2',
  prompt: 'Explain quantum computing'
)
```

### 2. Explicit Vendor Selection

```ruby
# Use specific vendor regardless of model name
response = LlmConductor.generate(
  model: 'gpt-4',
  vendor: :openrouter,  # Override auto-detection
  prompt: 'Your prompt'
)
```

### 3. Template-Based Generation

```ruby
# Vendor auto-detected based on model
response = LlmConductor.generate(
  model: 'gpt-4o-mini',      # → OpenAI
  type: :summarize_description,
  data: {
    name: 'TechCorp',
    description: 'AI company...'
  }
)
```

### 4. Using Defaults

```ruby
# Uses default_model and default_vendor from configuration
response = LlmConductor.generate(
  prompt: 'Your prompt'  # Uses configured defaults
)
```

## Environment-Specific Configuration

### Development Environment

```ruby
# config/environments/development.rb or similar
LlmConductor.configure do |config|
  # Use faster, cheaper models for development
  config.default_model = 'gpt-3.5-turbo'
  
  # Prefer local Ollama for development
  config.default_vendor = :ollama
  config.ollama(base_url: 'http://localhost:11434')
  
  # Shorter timeouts for quick feedback
  config.timeout = 15
  config.max_retries = 1
end
```

### Production Environment

```ruby
# config/environments/production.rb or similar
LlmConductor.configure do |config|
  # Use high-quality models for production
  config.default_model = 'gpt-4o-mini'
  config.default_vendor = :openai
  
  # Robust error handling
  config.timeout = 60
  config.max_retries = 3
  config.retry_delay = 2.0
  
  # Production API keys
  config.openai(
    api_key: ENV['OPENAI_API_KEY'],
    organization: ENV['OPENAI_ORG_ID']
  )
end
```

### Testing Environment

```ruby
# config/environments/test.rb or in spec_helper.rb
LlmConductor.configure do |config|
  # Mock configuration for testing
  config.default_model = 'gpt-3.5-turbo'
  config.timeout = 5  # Short timeouts
  config.max_retries = 0  # No retries in tests
end
```

## Advanced Configuration

### Custom Client Configuration

```ruby
LlmConductor.configure do |config|
  # Pass custom options to underlying HTTP clients
  config.openai(
    api_key: ENV['OPENAI_API_KEY'],
    timeout: 30,
    request_timeout: 30,
    read_timeout: 30
  )
  
  config.openrouter(
    api_key: ENV['OPENROUTER_API_KEY'],
    custom_headers: {
      'HTTP-Referer' => 'https://your-domain.com',
      'X-Title' => 'Your App Name'
    }
  )
end
```

### Dynamic Configuration

```ruby
# Configuration can be changed at runtime
def configure_for_user(user)
  LlmConductor.configure do |config|
    if user.premium?
      config.default_model = 'gpt-4'
      config.timeout = 120
    else
      config.default_model = 'gpt-3.5-turbo'  
      config.timeout = 30
    end
  end
end
```

## Configuration Validation

### Check Provider Configuration

```ruby
# Access provider-specific configuration
openai_config = LlmConductor.configuration.provider_config(:openai)
puts "OpenAI API Key configured: #{!openai_config[:api_key].nil?}"

ollama_config = LlmConductor.configuration.provider_config(:ollama)
puts "Ollama URL: #{ollama_config[:base_url]}"
```

### Validate Configuration

```ruby
def validate_llm_config
  config = LlmConductor.configuration
  
  errors = []
  errors << "OpenAI API key missing" if config.provider_config(:openai)[:api_key].nil?
  errors << "OpenRouter API key missing" if config.provider_config(:openrouter)[:api_key].nil?
  
  if errors.any?
    raise "Configuration errors: #{errors.join(', ')}"
  end
end
```

## Troubleshooting

### Common Issues

#### 1. "API key not configured"
```ruby
# Ensure your API keys are set
puts ENV['OPENAI_API_KEY']&.length  # Should show key length, not nil

# Or check configuration
config = LlmConductor.configuration.provider_config(:openai)
puts config[:api_key]&.length
```

#### 2. "Wrong vendor selected"
```ruby
# Force specific vendor if auto-detection fails
response = LlmConductor.generate(
  model: 'your-model',
  vendor: :openrouter,  # Explicit vendor
  prompt: 'Your prompt'
)
```

#### 3. "Timeout errors"
```ruby
# Increase timeout for complex queries
LlmConductor.configure do |config|
  config.timeout = 120  # 2 minutes
end
```

#### 4. "Ollama connection refused"
```ruby
# Check Ollama server status
config = LlmConductor.configuration.provider_config(:ollama)
puts "Ollama URL: #{config[:base_url]}"

# Test connection (outside gem)
require 'net/http'
uri = URI(config[:base_url])
begin
  response = Net::HTTP.get_response(uri)
  puts "Ollama status: #{response.code}"
rescue => e
  puts "Ollama connection error: #{e.message}"
end
```

## Legacy Compatibility

The gem maintains backward compatibility with older configuration methods:

```ruby
# Legacy style (still supported)
LlmConductor.configuration.openai_api_key = 'your-key'
LlmConductor.configuration.openrouter_api_key = 'your-key'
LlmConductor.configuration.ollama_address = 'http://localhost:11434'

# Modern style (recommended)
LlmConductor.configure do |config|
  config.openai(api_key: 'your-key')
  config.openrouter(api_key: 'your-key')
  config.ollama(base_url: 'http://localhost:11434')
end
```

## Best Practices

1. **Use Environment Variables** - Never hard-code API keys
2. **Configure Per Environment** - Different settings for dev/test/prod
3. **Set Reasonable Timeouts** - Balance responsiveness and reliability
4. **Test Your Configuration** - Validate settings before deployment
5. **Use Vendor Auto-Detection** - Let the gem choose the right provider
6. **Monitor Costs** - Track token usage and estimated costs
7. **Handle Errors Gracefully** - Always check `response.success?`

This configuration system provides maximum flexibility while maintaining simplicity and security.