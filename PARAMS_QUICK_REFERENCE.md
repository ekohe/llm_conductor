# Custom Parameters - Quick Reference

## 🚀 Quick Start

```ruby
# Add params to any generate call
LlmConductor.generate(
  model: 'llama2',
  prompt: 'Your prompt',
  vendor: :ollama,
  params: { temperature: 0.7 }  # ← New!
)
```

## 📊 Temperature Guide

| Value | Behavior | Use Case |
|-------|----------|----------|
| 0.0 | Deterministic | Testing, data extraction, exact answers |
| 0.3 | Very focused | Factual Q&A, summaries |
| 0.5 | Balanced & focused | General purpose, explanations |
| 0.7 | **Balanced (default)** | Most common use case |
| 0.9 | Creative | Stories, brainstorming |
| 1.2+ | Very creative | Experimental, very diverse |

## 🎯 Common Patterns

### Deterministic (Testing)
```ruby
params: { temperature: 0.0, seed: 42 }
```

### Creative Writing
```ruby
params: { temperature: 0.9, top_p: 0.95, repeat_penalty: 1.2 }
```

### Factual/Precise
```ruby
params: { temperature: 0.3, top_p: 0.85 }
```

### Long Content
```ruby
params: { temperature: 0.8, num_predict: 1000 }
```

## 📝 Ollama Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `temperature` | Float | 0.8 | Randomness (0.0-2.0) |
| `top_p` | Float | 0.9 | Nucleus sampling |
| `top_k` | Integer | 40 | Top-k sampling |
| `num_predict` | Integer | 128 | Max output tokens |
| `repeat_penalty` | Float | 1.1 | Reduce repetition |
| `seed` | Integer | - | For reproducibility |

[See full list →](PARAMS_USAGE.md#ollama-parameters-reference)

## 💡 Usage Examples

### With Simple Prompt
```ruby
response = LlmConductor.generate(
  model: 'llama2',
  prompt: 'Explain AI',
  vendor: :ollama,
  params: { temperature: 0.7, top_p: 0.9 }
)
```

### With Template
```ruby
response = LlmConductor.generate(
  model: 'llama2',
  type: :summarize_text,
  data: { text: '...' },
  vendor: :ollama,
  params: { temperature: 0.5 }
)
```

### With Client Builder
```ruby
client = LlmConductor.build_client(
  model: 'llama2',
  type: :custom,
  vendor: :ollama,
  params: { temperature: 0.3 }
)

response = client.generate_simple(prompt: '...')
```

## 🔧 Provider Support

| Provider | Status | Coming Soon |
|----------|--------|-------------|
| **Ollama** | ✅ Supported | - |
| OpenAI | 🔜 | Yes |
| Anthropic | 🔜 | Yes |
| Gemini | 🔜 | Yes |
| Groq | 🔜 | Yes |
| OpenRouter | 🔜 | Yes |
| Z.ai | 🔜 | Yes |

## 📚 Documentation

- **[PARAMS_USAGE.md](PARAMS_USAGE.md)** - Complete guide (200+ lines)
- **[examples/ollama_params_usage.rb](examples/ollama_params_usage.rb)** - Working examples
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Technical details
- **[CHANGELOG_PARAMS.md](CHANGELOG_PARAMS.md)** - What changed

## ⚡ Pro Tips

1. **Start with 0.7** - Good default for most use cases
2. **Use seed** - For reproducible results in testing
3. **Adjust top_p + temperature together** - They work in combination
4. **Limit tokens** - Use `num_predict` to control output length
5. **Reduce repetition** - Increase `repeat_penalty` if needed

## 🐛 Troubleshooting

**Params not working?**
- Check spelling (case-sensitive)
- Verify provider supports the param
- Check value type (int vs float)

**Output too random?**
- Lower temperature (try 0.3-0.5)
- Lower top_p (try 0.85)

**Output too repetitive?**
- Increase repeat_penalty (try 1.2-1.5)
- Increase temperature slightly

**Output too short?**
- Increase num_predict
- Check if model hit token limit

## 🎓 Learn More

- [Ollama Params Docs](https://github.com/ollama/ollama/blob/main/docs/modelfile.md)
- [Temperature Explained](https://docs.cohere.com/docs/temperature)
- [Nucleus Sampling Paper](https://arxiv.org/abs/1904.09751)

## 🆘 Need Help?

See the full documentation:
```bash
cat PARAMS_USAGE.md
ruby examples/ollama_params_usage.rb
```

