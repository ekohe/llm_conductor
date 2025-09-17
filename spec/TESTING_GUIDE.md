# Testing Guide for LlmConductor Gem

This document provides an overview of the comprehensive test suite for the LlmConductor gem.

## Test Structure

The test suite is organized into several categories:

### Unit Tests
- **Configuration**: Tests for configuration management and environment variable handling
- **Client Factory**: Tests for client instantiation logic and vendor selection
- **Base Client**: Tests for shared client functionality including token calculation
- **Individual Clients**: Tests for GPT, Ollama, and OpenRouter client implementations
- **Prompts Module**: Tests for all prompt generation methods

### Integration Tests
- **End-to-End Workflows**: Full client creation and content generation flows
- **Multi-vendor Integration**: Tests across different LLM providers
- **Configuration Integration**: Dynamic configuration changes
- **Error Scenarios**: Comprehensive error handling across the stack

### Performance Tests
- **Client Creation Performance**: Benchmarks for efficient client instantiation
- **Memory Usage**: Tests to ensure no memory leaks
- **Concurrent Access**: Multi-threading safety tests
- **Large Data Handling**: Performance with large prompts and responses

### Error Handling Tests
- **API Errors**: Network failures, authentication issues, malformed responses
- **Configuration Errors**: Missing API keys, invalid addresses
- **Prompt Errors**: Invalid prompt types, missing template data
- **Token Calculation Errors**: Encoding failures

## Running Tests

### All Tests
```bash
bundle exec rspec
```

### Specific Test Categories
```bash
# Unit tests only
bundle exec rspec spec/llm_conductor/configuration_spec.rb
bundle exec rspec spec/llm_conductor/client_factory_spec.rb
bundle exec rspec spec/llm_conductor/clients/

# Integration tests
bundle exec rspec spec/llm_conductor/integration_spec.rb

# Performance tests
bundle exec rspec spec/llm_conductor/performance_spec.rb

# Error handling tests
bundle exec rspec spec/llm_conductor/error_handling_spec.rb
```

### Test Output Formats
```bash
# Documentation format (detailed)
bundle exec rspec --format documentation

# Progress format (simple)
bundle exec rspec --format progress

# JSON format (for CI)
bundle exec rspec --format json
```

## Test Coverage

The test suite achieves comprehensive coverage across:

- ✅ **100 test examples** covering all major functionality
- ✅ **Unit tests** for each module and class
- ✅ **Integration tests** for end-to-end workflows  
- ✅ **Performance benchmarks** for efficiency validation
- ✅ **Error handling** for robust failure scenarios
- ✅ **Multi-vendor support** (OpenAI, OpenRouter, Ollama)
- ✅ **Configuration management** with dynamic changes
- ✅ **Memory and concurrency safety**

## Key Features Tested

### Client Creation & Management
- Automatic vendor detection based on model names
- Configuration-driven client instantiation
- Client memoization for performance
- Thread-safe concurrent access

### Prompt Generation
- All prompt types: featured_links, summarize_htmls, summarize_description, custom
- Template interpolation with error handling
- Large data handling efficiency
- Missing data graceful degradation

### Content Generation
- Full request/response cycles for all providers
- Token counting with tiktoken integration
- Error propagation from APIs
- Response parsing and extraction

### Configuration System
- Environment variable integration
- Dynamic configuration updates
- Validation and error handling
- Provider-specific settings

## Continuous Integration

The test suite is designed to run efficiently in CI environments:

- **Fast execution**: ~0.1 seconds for 100 tests
- **No external dependencies**: All API calls are mocked
- **Deterministic results**: No flaky tests
- **Comprehensive coverage**: Catches regressions effectively

## Development Workflow

When adding new features:

1. Write failing tests first (TDD approach)
2. Implement the feature to make tests pass
3. Add integration tests for end-to-end validation
4. Add performance tests if applicable
5. Update error handling tests for new failure modes

## Mock Strategy

The test suite uses comprehensive mocking to:

- **Avoid external API calls** during testing
- **Control response scenarios** for edge case testing
- **Ensure fast, deterministic test execution**
- **Test error conditions** that are hard to reproduce with real APIs

All external dependencies (OpenAI, Ollama APIs, tiktoken) are properly mocked while preserving the actual interface contracts.
