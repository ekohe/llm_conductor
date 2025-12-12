# Custom Parameters Guide

Fine-tune LLM generation behavior with parameters like `temperature`, `top_p`, and more.

## 🚀 Quick Reference

### Temperature Guide
| Value | Behavior | Use Case |
|-------|----------|----------|
| 0.0 | Deterministic | Testing, data extraction |
| 0.3 | Very focused | Factual Q&A, summaries |
| 0.7 | **Balanced (recommended)** | General purpose |
| 0.9 | Creative | Stories, brainstorming |

### Common Patterns

```ruby
# Deterministic (testing)
params: { temperature: 0.0, seed: 42 }

# Creative writing
params: { temperature: 0.9, top_p: 0.95, repeat_penalty: 1.2 }

# Factual/precise
params: { temperature: 0.3, top_p: 0.85 }
```

### Provider Support
| Provider | Status |
|----------|--------|
| Ollama | ✅ Supported |
| OpenAI, Anthropic, Gemini, etc. | 🔜 Coming soon |

---

## Overview

Custom parameters allow you to control various aspects of LLM generation:
- **Temperature**: Controls randomness (0.0 = deterministic, higher = more creative)
- **Top-p/Top-k**: Controls diversity via nucleus/top-k sampling
- **Max tokens**: Limits the length of generated responses
- **And more**: Each provider supports different parameters

## Quick Start

```ruby
require 'llm_conductor'

# Generate with custom temperature
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Write a creative story.',
  vendor: :ollama,
  params: { temperature: 0.9 }
)
```

## Usage Examples

### 1. Simple Prompt with Parameters

```ruby
# Low temperature for focused, deterministic output
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'What is 2 + 2?',
  vendor: :ollama,
  params: { temperature: 0.0 }
)

# High temperature for creative output
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Write a poem about the ocean.',
  vendor: :ollama,
  params: { temperature: 0.9 }
)
```

### 2. Multiple Parameters

```ruby
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Explain quantum computing.',
  vendor: :ollama,
  params: {
    temperature: 0.7,
    top_p: 0.9,
    top_k: 40,
    num_predict: 200,      # Max tokens
    repeat_penalty: 1.1    # Penalize repetition
  }
)
```

### 3. Using build_client with Parameters

```ruby
# Create a client with custom parameters
client = LlmConductor.build_client(
  model: 'llama2',
  type: :custom,
  vendor: :ollama,
  params: {
    temperature: 0.3,
    repeat_penalty: 1.2
  }
)

# Use the client
response = client.generate_simple(
  prompt: 'List 5 benefits of exercise.'
)
```

### 4. Template-Based Generation with Parameters

```ruby
# Using params with template-based generation
response = LlmConductor.generate(
  model: 'llama2',
  type: :summarize_text,
  data: { 
    content: 'Long article text here...',
    max_length: 100 
  },
  vendor: :ollama,
  params: {
    temperature: 0.5,
    num_predict: 150
  }
)
```

## Ollama Parameters Reference

Below are common parameters supported by Ollama. For a complete list, see the [Ollama documentation](https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values).

### Core Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `temperature` | Float | 0.8 | Controls randomness. 0.0 = deterministic, 2.0 = very random |
| `top_p` | Float | 0.9 | Nucleus sampling. Controls diversity (0.0-1.0) |
| `top_k` | Integer | 40 | Top-k sampling. Limits vocabulary to top K tokens |
| `num_predict` | Integer | 128 | Maximum number of tokens to generate |
| `repeat_penalty` | Float | 1.1 | Penalizes repetition. 1.0 = no penalty |

### Advanced Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `seed` | Integer | Random seed for reproducibility |
| `stop` | Array<String> | Stop sequences that end generation |
| `tfs_z` | Float | Tail-free sampling parameter |
| `num_ctx` | Integer | Context window size |
| `num_gpu` | Integer | Number of layers to offload to GPU |
| `num_thread` | Integer | Number of threads to use |
| `repeat_last_n` | Integer | Look back for repetition penalty |
| `mirostat` | Integer | Enable Mirostat sampling (0, 1, or 2) |
| `mirostat_tau` | Float | Mirostat target entropy |
| `mirostat_eta` | Float | Mirostat learning rate |

## Common Use Cases

### Deterministic Output (Testing, Structured Data)

For consistent, reproducible results:

```ruby
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Extract the email addresses from this text...',
  vendor: :ollama,
  params: { 
    temperature: 0.0,
    seed: 42  # Optional: ensures reproducibility
  }
)
```

### Creative Writing

For more varied, creative responses:

```ruby
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Write a short science fiction story.',
  vendor: :ollama,
  params: { 
    temperature: 0.9,
    top_p: 0.95,
    repeat_penalty: 1.2
  }
)
```

### Balanced (General Purpose)

Good middle ground for most tasks:

```ruby
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Explain how photosynthesis works.',
  vendor: :ollama,
  params: { 
    temperature: 0.7,
    top_p: 0.9
  }
)
```

### Long-Form Content

For generating longer responses:

```ruby
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Write a detailed guide on...',
  vendor: :ollama,
  params: { 
    temperature: 0.8,
    num_predict: 1000,  # Allow up to 1000 tokens
    repeat_penalty: 1.1
  }
)
```

## Best Practices

### 1. Temperature Guidelines

- **0.0-0.3**: Deterministic, focused, factual responses
  - Use for: Data extraction, structured output, factual questions
- **0.4-0.7**: Balanced responses with some variation
  - Use for: General Q&A, summaries, explanations
- **0.8-1.2**: Creative, diverse responses
  - Use for: Creative writing, brainstorming, storytelling
- **1.3+**: Very random, experimental
  - Use with caution: May produce incoherent output

### 2. Combining Parameters

Temperature and top_p work together:

```ruby
# Conservative: Focused but with some diversity
params: { temperature: 0.5, top_p: 0.9 }

# Balanced: Good for most use cases
params: { temperature: 0.7, top_p: 0.9, top_k: 40 }

# Creative: Maximum diversity
params: { temperature: 1.0, top_p: 0.95 }
```

### 3. Reproducibility

For testing or debugging, use a fixed seed:

```ruby
params: { 
  temperature: 0.5, 
  seed: 12345  # Same seed + same params = same output
}
```

### 4. Performance Tuning

```ruby
# Optimize for speed
params: { 
  num_predict: 100,    # Limit output length
  num_thread: 8        # Use more CPU threads
}

# Optimize for quality
params: { 
  num_ctx: 4096,       # Larger context window
  repeat_penalty: 1.2  # Reduce repetition
}
```

## Configuration

You can set default parameters at the configuration level (future enhancement):

```ruby
# Coming soon - configuration-level defaults
LlmConductor.configure do |config|
  config.ollama(
    base_url: 'http://localhost:11434',
    default_params: { temperature: 0.7, top_p: 0.9 }
  )
end
```

## Parameter Validation

The gem passes parameters directly to the underlying provider. Invalid parameters will:
- Be ignored by the provider (most common)
- Return an error from the provider API

Always refer to your provider's documentation for supported parameters.

## Future Provider Support

Currently, custom parameters are fully supported for:
- ✅ **Ollama**

Coming soon:
- 🔜 OpenAI (GPT)
- 🔜 Anthropic (Claude)
- 🔜 Google (Gemini)
- 🔜 Groq
- 🔜 OpenRouter
- 🔜 Z.ai

## Troubleshooting

### Parameters Not Working

1. Check parameter spelling (case-sensitive)
2. Verify your provider supports the parameter
3. Check parameter value types (integer vs float vs string)

### Unexpected Output

1. Try lowering temperature for more consistent results
2. Adjust top_p and top_k for better quality
3. Increase repeat_penalty if output is too repetitive

### Performance Issues

1. Reduce `num_predict` to limit output length
2. Adjust `num_thread` based on your CPU
3. Use `num_gpu` to offload processing to GPU

## Examples

See the complete example file: [examples/ollama_params_usage.rb](examples/ollama_params_usage.rb)

## Resources

- [Ollama Parameters Documentation](https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values)
- [Temperature in Language Models](https://docs.cohere.com/docs/temperature)
- [Nucleus Sampling (Top-p)](https://arxiv.org/abs/1904.09751)

