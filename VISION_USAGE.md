# Vision/Multimodal Usage Guide

This guide explains how to use vision/multimodal capabilities with LLM Conductor. Vision support is available for Claude (Anthropic), GPT (OpenAI), Gemini (Google), OpenRouter, and Z.ai clients.

## Quick Start

### Using Claude (Anthropic)

```ruby
require 'llm_conductor'

# Configure
LlmConductor.configure do |config|
  config.anthropic(api_key: ENV['ANTHROPIC_API_KEY'])
end

# Analyze an image
response = LlmConductor.generate(
  model: 'claude-sonnet-4-20250514',
  vendor: :anthropic,
  prompt: {
    text: 'What is in this image?',
    images: 'https://example.com/image.jpg'
  }
)

puts response.output
```

### Using GPT (OpenAI)

```ruby
require 'llm_conductor'

# Configure
LlmConductor.configure do |config|
  config.openai(api_key: ENV['OPENAI_API_KEY'])
end

# Analyze an image
response = LlmConductor.generate(
  model: 'gpt-4o',
  vendor: :openai,
  prompt: {
    text: 'What is in this image?',
    images: 'https://example.com/image.jpg'
  }
)

puts response.output
```

### Using OpenRouter

```ruby
require 'llm_conductor'

# Configure
LlmConductor.configure do |config|
  config.openrouter(api_key: ENV['OPENROUTER_API_KEY'])
end

# Analyze an image
response = LlmConductor.generate(
  model: 'openai/gpt-4o-mini',
  vendor: :openrouter,
  prompt: {
    text: 'What is in this image?',
    images: 'https://example.com/image.jpg'
  }
)

puts response.output
```

### Using Gemini (Google)

```ruby
require 'llm_conductor'

# Configure
LlmConductor.configure do |config|
  config.gemini(api_key: ENV['GEMINI_API_KEY'])
end

# Analyze an image
response = LlmConductor.generate(
  model: 'gemini-2.5-flash',
  vendor: :gemini,
  prompt: {
    text: 'What is in this image?',
    images: 'https://cdn.autonomous.ai/production/ecm/230930/10-Comfortable-Office-Chairs-for-Gaming-A-Comprehensive-Review00002.webp'
  }
)

puts response.output
```

### Using Z.ai (Zhipu AI)

```ruby
require 'llm_conductor'

# Configure
LlmConductor.configure do |config|
  config.zai(api_key: ENV['ZAI_API_KEY'])
end

# Analyze an image with GLM-4.5V
response = LlmConductor.generate(
  model: 'glm-4.5v',
  vendor: :zai,
  prompt: {
    text: 'What is in this image?',
    images: 'https://example.com/image.jpg'
  }
)

puts response.output
```

## Recommended Models

### Claude Models (Anthropic)

For vision tasks via Anthropic API:

- **`claude-sonnet-4-20250514`** - Claude Sonnet 4 (latest, best for vision) ✅
- **`claude-opus-4-20250514`** - Claude Opus 4 (maximum quality)
- **`claude-opus-4-1-20250805`** - Claude Opus 4.1 (newest flagship model)

### GPT Models (OpenAI)

For vision tasks via OpenAI API:

- **`gpt-4o`** - Latest GPT-4 Omni with advanced vision capabilities ✅
- **`gpt-4o-mini`** - Fast, cost-effective vision model
- **`gpt-4-turbo`** - Previous generation with vision support
- **`gpt-4-vision-preview`** - Legacy vision model (deprecated)

### OpenRouter Models

For vision tasks via OpenRouter, these models work reliably:

- **`openai/gpt-4o-mini`** - Fast, reliable, good balance of cost/quality ✅
- **`google/gemini-flash-1.5`** - Fast vision processing
- **`anthropic/claude-3.5-sonnet`** - High quality analysis
- **`openai/gpt-4o`** - Best quality (higher cost)

### Gemini Models (Google)

For vision tasks via Google Gemini API:

- **`gemini-2.0-flash`** - Gemini 2.0 Flash (fast, efficient, multimodal) ✅
- **`gemini-2.5-flash`** - Gemini 2.5 Flash (latest fast model)
- **`gemini-1.5-pro`** - Gemini 1.5 Pro (high quality, large context window)
- **`gemini-1.5-flash`** - Gemini 1.5 Flash (previous generation fast model)

**Note:** Gemini client automatically fetches images from URLs and encodes them as base64, as required by the Gemini API.

### Z.ai Models (Zhipu AI)

For vision tasks via Z.ai, these GLM models are recommended:

- **`glm-4.5v`** - GLM-4.5V multimodal model (64K context window) ✅
- **`glm-4-plus`** - Text-only model with enhanced capabilities
- **`glm-4v`** - Previous generation vision model

## Usage Formats

### 1. Single Image (Simple Format)

```ruby
response = LlmConductor.generate(
  model: 'openai/gpt-4o-mini',
  vendor: :openrouter,
  prompt: {
    text: 'Describe this image',
    images: 'https://example.com/image.jpg'
  }
)
```

### 2. Multiple Images

```ruby
response = LlmConductor.generate(
  model: 'openai/gpt-4o-mini',
  vendor: :openrouter,
  prompt: {
    text: 'Compare these images',
    images: [
      'https://example.com/image1.jpg',
      'https://example.com/image2.jpg',
      'https://example.com/image3.jpg'
    ]
  }
)
```

### 3. Image with Detail Level

For high-resolution images, specify the detail level (supported by GPT and OpenRouter):

```ruby
response = LlmConductor.generate(
  model: 'gpt-4o',
  vendor: :openai,
  prompt: {
    text: 'Analyze this image in detail',
    images: [
      { url: 'https://example.com/hires-image.jpg', detail: 'high' }
    ]
  }
)
```

Detail levels (GPT and OpenRouter only):
- `'high'` - Better for detailed analysis (uses more tokens)
- `'low'` - Faster, cheaper (default if not specified)
- `'auto'` - Let the model decide

**Note:** Claude (Anthropic), Gemini (Google), and Z.ai don't support the `detail` parameter.

### 4. Raw Format (Advanced)

For maximum control, use provider-specific array formats:

**GPT/OpenRouter Format:**
```ruby
response = LlmConductor.generate(
  model: 'gpt-4o',
  vendor: :openai,
  prompt: [
    { type: 'text', text: 'What is in this image?' },
    { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } },
    { type: 'text', text: 'Describe it in detail.' }
  ]
)
```

**Claude Format:**
```ruby
response = LlmConductor.generate(
  model: 'claude-sonnet-4-20250514',
  vendor: :anthropic,
  prompt: [
    { type: 'image', source: { type: 'url', url: 'https://example.com/image.jpg' } },
    { type: 'text', text: 'What is in this image? Describe it in detail.' }
  ]
)
```

**Gemini Format:**
```ruby
response = LlmConductor.generate(
  model: 'gemini-2.0-flash',
  vendor: :gemini,
  prompt: [
    { type: 'text', text: 'What is in this image? Describe it in detail.' },
    { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } }
  ]
)
```

## Text-Only Requests (Backward Compatible)

The client still supports regular text-only requests:

```ruby
response = LlmConductor.generate(
  model: 'openai/gpt-4o-mini',
  vendor: :openrouter,
  prompt: 'What is the capital of France?'
)
```

## Image URL Requirements

- Images must be publicly accessible URLs
- Supported formats: JPEG, PNG, GIF, WebP
- Maximum file size depends on the model
- Use HTTPS URLs when possible

**Provider-Specific Notes:**
- **Gemini**: URLs are automatically fetched and base64-encoded by the client before sending to the API
- **Claude, GPT, OpenRouter, Z.ai**: URLs are sent directly to the API (no preprocessing required)

## Error Handling

```ruby
response = LlmConductor.generate(
  model: 'openai/gpt-4o-mini',
  vendor: :openrouter,
  prompt: {
    text: 'Analyze this',
    images: 'https://example.com/image.jpg'
  }
)

if response.success?
  puts response.output
else
  puts "Error: #{response.metadata[:error]}"
end
```

## Testing in Development

### Interactive Console

```bash
./bin/console
```

Then:

```ruby
LlmConductor.configure do |config|
  config.openrouter(api_key: 'your-key')
end

response = LlmConductor.generate(
  model: 'openai/gpt-4o-mini',
  vendor: :openrouter,
  prompt: {
    text: 'What is this?',
    images: 'https://example.com/image.jpg'
  }
)
```

### Run Examples

For Claude:
```bash
export ANTHROPIC_API_KEY='your-key'
ruby examples/claude_vision_usage.rb
```

For GPT:
```bash
export OPENAI_API_KEY='your-key'
ruby examples/gpt_vision_usage.rb
```

For OpenRouter:
```bash
export OPENROUTER_API_KEY='your-key'
ruby examples/openrouter_vision_usage.rb
```

For Gemini:
```bash
export GEMINI_API_KEY='your-key'
ruby examples/gemini_vision_usage.rb
```

For Z.ai:
```bash
export ZAI_API_KEY='your-key'
ruby examples/zai_usage.rb
```

## Token Counting

Token counting for multimodal requests counts only the text portion. Image tokens vary by:
- Image size
- Detail level specified
- Model being used

The gem provides an approximation based on text tokens. For precise billing, check the OpenRouter dashboard.

## Common Issues

### 502 Server Error

If you get a 502 error:
- The model might be unavailable
- Try a different model (e.g., switch to `openai/gpt-4o-mini`)
- Free tier models may be overloaded

### "No implicit conversion of Hash into String"

This was fixed in the current version. Make sure you're using the latest version of the gem.

### Image Not Loading

- Verify the URL is publicly accessible
- Check that the image format is supported
- Try a smaller image size

## Cost Considerations

Vision models are more expensive than text-only models. Costs vary by:

- **Model choice**: GPT-4o > GPT-4o-mini > Gemini Flash
- **Detail level**: `high` uses more tokens than `low`
- **Image count**: Each image adds to the cost
- **Image size**: Larger images may use more tokens

For development, use:
- `openai/gpt-4o-mini` for cost-effective testing
- `detail: 'low'` for quick analysis
- Single images when possible

For production:
- Use `openai/gpt-4o` for best quality
- Use `detail: 'high'` when needed
- Monitor costs via OpenRouter dashboard

## Examples

- `examples/claude_vision_usage.rb` - Complete Claude vision examples with Claude Sonnet 4
- `examples/gpt_vision_usage.rb` - Complete GPT vision examples with GPT-4o
- `examples/gemini_vision_usage.rb` - Complete Gemini vision examples with Gemini 2.0 Flash
- `examples/openrouter_vision_usage.rb` - Complete OpenRouter vision examples
- `examples/zai_usage.rb` - Complete Z.ai GLM-4.5V examples including vision and text

## Further Reading

- [OpenRouter Documentation](https://openrouter.ai/docs)
- [OpenAI Vision API Reference](https://platform.openai.com/docs/guides/vision)
- [Anthropic Claude Vision](https://docs.anthropic.com/claude/docs/vision)
- [Google Gemini API Documentation](https://ai.google.dev/docs)
- [Z.ai API Platform](https://api.z.ai/)
- [GLM-4.5V Documentation](https://bigmodel.cn/)

