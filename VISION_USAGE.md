# Vision/Multimodal Usage Guide

This guide explains how to use vision/multimodal capabilities with the OpenRouter and Z.ai clients in LLM Conductor.

## Quick Start

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

### OpenRouter Models

For vision tasks via OpenRouter, these models work reliably:

- **`openai/gpt-4o-mini`** - Fast, reliable, good balance of cost/quality ✅
- **`google/gemini-flash-1.5`** - Fast vision processing
- **`anthropic/claude-3.5-sonnet`** - High quality analysis
- **`openai/gpt-4o`** - Best quality (higher cost)

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

For high-resolution images, specify the detail level:

```ruby
response = LlmConductor.generate(
  model: 'openai/gpt-4o-mini',
  vendor: :openrouter,
  prompt: {
    text: 'Analyze this image in detail',
    images: [
      { url: 'https://example.com/hires-image.jpg', detail: 'high' }
    ]
  }
)
```

Detail levels:
- `'high'` - Better for detailed analysis (uses more tokens)
- `'low'` - Faster, cheaper (default if not specified)
- `'auto'` - Let the model decide

### 4. Raw Format (Advanced)

For maximum control, use the OpenAI-compatible array format:

```ruby
response = LlmConductor.generate(
  model: 'openai/gpt-4o-mini',
  vendor: :openrouter,
  prompt: [
    { type: 'text', text: 'What is in this image?' },
    { type: 'image_url', image_url: { url: 'https://example.com/image.jpg' } },
    { type: 'text', text: 'Describe it in detail.' }
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

For OpenRouter:
```bash
export OPENROUTER_API_KEY='your-key'
ruby examples/openrouter_vision_usage.rb
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

- `examples/openrouter_vision_usage.rb` - Complete OpenRouter vision examples
- `examples/zai_usage.rb` - Complete Z.ai GLM-4.5V examples including vision and text

## Further Reading

- [OpenRouter Documentation](https://openrouter.ai/docs)
- [OpenAI Vision API Reference](https://platform.openai.com/docs/guides/vision)
- [Anthropic Claude Vision](https://docs.anthropic.com/claude/docs/vision)
- [Z.ai API Platform](https://api.z.ai/)
- [GLM-4.5V Documentation](https://bigmodel.cn/)

