# LLM Conductor Testing Guide (Comprehensive)

This guide covers the comprehensive testing strategy for LLM Conductor, including unit tests, integration tests, performance tests, and best practices for testing LLM-based applications.

For the full comprehensive testing guide including 234+ test examples, error handling patterns, performance testing, and migration strategies, please see the main repository documentation.

## Quick Overview

**Current Test Statistics**: 234+ tests, 0 failures  
**Coverage Areas**: Unit (60%), Integration (25%), Performance (10%), Error Handling (5%)  
**Test Categories**: Configuration, Clients, Response Objects, Prompt Management, Data Builders

## Key Testing Areas

### 1. Response Object Testing
All methods now return `LlmConductor::Response` objects instead of hashes:

```ruby
RSpec.describe 'Response handling' do
  let(:response) do
    LlmConductor::Response.new(
      output: 'Generated text',
      model: 'gpt-4',
      input_tokens: 10,
      output_tokens: 15,
      metadata: { vendor: :openai }
    )
  end

  it 'provides complete response data' do
    expect(response.success?).to be true
    expect(response.total_tokens).to eq(25)
    expect(response.estimated_cost).to be_a(Numeric)
  end
end
```

### 2. Mocking Best Practices
Always mock LLM API calls in tests:

```ruby
RSpec.describe SomeClass do
  before do
    allow(LlmConductor).to receive(:generate).and_return(
      instance_double(
        LlmConductor::Response,
        success?: true,
        output: 'Mocked response',
        total_tokens: 25,
        estimated_cost: 0.001
      )
    )
  end
end
```

### 3. Error Handling Tests
Test both success and failure scenarios:

```ruby
it 'handles LLM failures gracefully' do
  response = instance_double(
    LlmConductor::Response,
    success?: false,
    metadata: { error: 'API rate limit exceeded' }
  )
  
  allow(LlmConductor).to receive(:generate).and_return(response)
  # Test error handling logic
end
```

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific categories
bundle exec rspec --tag unit
bundle exec rspec --tag integration
bundle exec rspec --tag performance

# Run with coverage
COVERAGE=true bundle exec rspec
```

## Migration Testing

When upgrading from 1.x to 2.0, update test expectations:

```ruby
# Old (1.x)
expect(result[:output]).to eq('expected')

# New (2.0)
expect(result.output).to eq('expected')
```

For comprehensive testing examples, migration strategies, and advanced patterns, see the full documentation in the main repository.
