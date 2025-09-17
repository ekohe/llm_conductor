# Prompt Registration System Guide

The LLM Conductor gem provides a powerful prompt registration system that allows you to create reusable, testable, and maintainable prompt classes. This guide covers everything you need to know about creating, registering, and using custom prompts.

## Overview

The prompt registration system allows you to:
- **Create reusable prompt classes** with inheritance and composition
- **Register prompts with memorable names** for easy reference
- **Use helper methods** for common formatting tasks
- **Test prompts independently** of LLM calls
- **Share prompts across projects** with consistent interfaces

## Quick Start

### 1. Create a Prompt Class

```ruby
class CompanyAnalysisPrompt < LlmConductor::Prompts::BasePrompt
  def render
    <<~PROMPT
      Company: #{name}
      Domain: #{domain_name}
      Description: #{truncate_text(description, max_length: 500)}

      Please analyze this company and provide:
      1. Business model
      2. Target market
      3. Growth potential

      Format as JSON.
    PROMPT
  end
end
```

### 2. Register the Prompt

```ruby
LlmConductor::PromptManager.register(:company_analysis, CompanyAnalysisPrompt)
```

### 3. Use the Registered Prompt

```ruby
response = LlmConductor.generate(
  model: 'gpt-4',
  type: :company_analysis,
  data: {
    name: 'TechCorp',
    domain_name: 'techcorp.com',
    description: 'A leading AI company specializing in...'
  }
)

# Parse structured response
analysis = response.parse_json
puts analysis['business_model']
```

## BasePrompt Class

All custom prompts should inherit from `LlmConductor::Prompts::BasePrompt`, which provides:

### Dynamic Data Access

Data passed to the prompt becomes accessible as methods:

```ruby
class ExamplePrompt < LlmConductor::Prompts::BasePrompt
  def render
    # Data can be accessed as methods
    "Company: #{name}"           # data[:name]
    "Location: #{location}"      # data[:location]
    "Founded: #{founded_year}"   # data[:founded_year]
  end
end

# Usage
response = LlmConductor.generate(
  type: :example,
  data: {
    name: 'TechCorp',
    location: 'San Francisco', 
    founded_year: 2020
  }
)
```

### Built-in Helper Methods

#### `truncate_text(text, max_length:)`
Safely truncates text to a maximum length:

```ruby
def render
  <<~PROMPT
    Description: #{truncate_text(description, max_length: 200)}
    
    Full description: #{description}
    Short version: #{truncate_text(description, max_length: 50)}
  PROMPT
end
```

#### `numbered_list(items)`
Creates a numbered list from an array:

```ruby
def render
  <<~PROMPT
    Key features:
    #{numbered_list(features)}
  PROMPT
end

# Input: ['AI-powered', 'Cloud-based', 'Scalable']
# Output: 
# 1. AI-powered
# 2. Cloud-based  
# 3. Scalable
```

#### `bulleted_list(items)`
Creates a bulleted list from an array:

```ruby
def render
  <<~PROMPT
    Services offered:
    #{bulleted_list(services)}
  PROMPT
end

# Input: ['Consulting', 'Development', 'Support']
# Output:
# • Consulting
# • Development
# • Support
```

#### `data_dig(*keys)`
Safely accesses nested data structures:

```ruby
def render
  <<~PROMPT
    Primary industry: #{data_dig(:company, :industries, 0)}
    Headquarters: #{data_dig(:company, :location, :city)}
  PROMPT
end

# Alias available as 'dig'
"Country: #{dig(:company, :location, :country)}"
```

## Advanced Prompt Patterns

### 1. Conditional Content

```ruby
class ConditionalPrompt < LlmConductor::Prompts::BasePrompt
  def render
    content = ["Company: #{name}"]
    
    # Conditional sections
    content << "Industry: #{industry}" if industry
    content << "Founded: #{founded_year}" if founded_year
    content << revenue_section if revenue
    
    content.join("\n\n")
  end

  private

  def revenue_section
    return unless revenue
    
    <<~SECTION
      Financial Information:
      - Annual Revenue: #{format_currency(revenue)}
      - Growth Rate: #{growth_rate}%
    SECTION
  end

  def format_currency(amount)
    "$#{amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end
end
```

### 2. Composition and Inheritance

```ruby
# Base class for all company prompts
class CompanyBasePrompt < LlmConductor::Prompts::BasePrompt
  protected

  def company_header
    <<~HEADER
      Company: #{name}
      Domain: #{domain_name}
      #{location_line}
    HEADER
  end

  def location_line
    return "" unless city || country
    
    location_parts = [city, country].compact
    "Location: #{location_parts.join(', ')}"
  end
end

# Specific analysis prompt
class TechnicalAnalysisPrompt < CompanyBasePrompt
  def render
    <<~PROMPT
      #{company_header}

      Technical Focus:
      #{numbered_list(technologies)}

      Please analyze the technical capabilities and provide:
      1. Technology stack assessment
      2. Innovation potential
      3. Technical competitive advantages
    PROMPT
  end
end

# Business analysis prompt  
class BusinessAnalysisPrompt < CompanyBasePrompt
  def render
    <<~PROMPT
      #{company_header}

      Business Overview:
      #{truncate_text(description, max_length: 300)}

      Please analyze the business aspects:
      1. Business model
      2. Market position
      3. Revenue potential
    PROMPT
  end
end
```

### 3. Template-Based Prompts

```ruby
class TemplatePrompt < LlmConductor::Prompts::BasePrompt
  def render
    base_template.gsub('{SECTIONS}', sections.join("\n\n"))
  end

  private

  def base_template
    <<~TEMPLATE
      Analyze the following company:

      {SECTIONS}

      Please provide a comprehensive analysis.
    TEMPLATE
  end

  def sections
    [
      company_section,
      business_section,
      technical_section
    ].compact
  end

  def company_section
    return nil unless name || domain_name
    
    "Company Information:\n- Name: #{name}\n- Domain: #{domain_name}"
  end

  def business_section
    return nil unless industry || revenue
    
    parts = []
    parts << "Industry: #{industry}" if industry
    parts << "Revenue: #{revenue}" if revenue
    "Business Details:\n#{parts.map { |p| "- #{p}" }.join("\n")}"
  end

  def technical_section
    return nil unless technologies&.any?
    
    "Technology Stack:\n#{bulleted_list(technologies)}"
  end
end
```

## Prompt Manager

The `LlmConductor::PromptManager` provides utilities for managing registered prompts:

### Registration

```ruby
# Register a prompt class
LlmConductor::PromptManager.register(:my_prompt, MyPromptClass)

# Register multiple prompts
{
  company_analysis: CompanyAnalysisPrompt,
  technical_review: TechnicalReviewPrompt,
  market_analysis: MarketAnalysisPrompt
}.each do |type, klass|
  LlmConductor::PromptManager.register(type, klass)
end
```

### Query Available Prompts

```ruby
# Get all registered prompt types
types = LlmConductor::PromptManager.types
puts "Available: #{types.join(', ')}"

# Check if a prompt is registered
if LlmConductor::PromptManager.registered?(:my_prompt)
  puts "Prompt is available"
end
```

### Preview Prompts

```ruby
# Render a prompt without making an LLM call
preview = LlmConductor::PromptManager.render(
  :company_analysis,
  {
    name: 'TechCorp',
    description: 'AI company...',
    industry: 'Technology'
  }
)

puts preview
```

### Remove Prompts

```ruby
# Remove a registered prompt (useful for testing)
LlmConductor::PromptManager.unregister(:my_prompt)

# Clear all prompts
LlmConductor::PromptManager.clear_all
```

## Real-World Examples

### 1. Multi-Stage Analysis Prompt

```ruby
class MultiStageAnalysisPrompt < LlmConductor::Prompts::BasePrompt
  def render
    <<~PROMPT
      #{company_overview}

      Analysis Instructions:
      #{analysis_stages}

      Output Requirements:
      #{output_format}
    PROMPT
  end

  private

  def company_overview
    <<~OVERVIEW
      Company Profile:
      #{bulleted_list(company_facts.compact)}
    OVERVIEW
  end

  def company_facts
    [
      name ? "Name: #{name}" : nil,
      domain_name ? "Domain: #{domain_name}" : nil,
      industry ? "Industry: #{industry}" : nil,
      employee_count ? "Employees: #{format_number(employee_count)}" : nil
    ]
  end

  def analysis_stages
    numbered_list([
      "Business Model Analysis - Identify revenue streams and value proposition",
      "Market Position Assessment - Evaluate competitive landscape",
      "Growth Potential Evaluation - Assess scalability and market opportunities",
      "Risk Assessment - Identify potential challenges and threats"
    ])
  end

  def output_format
    <<~FORMAT
      Please structure your response as JSON with these keys:
      - business_model: { revenue_streams: [], value_proposition: "" }
      - market_position: { competitors: [], market_share: "", advantages: [] }
      - growth_potential: { score: 1-10, factors: [], timeline: "" }
      - risks: { high: [], medium: [], low: [] }
    FORMAT
  end

  def format_number(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
```

### 2. Contextual Prompt with Conditional Logic

```ruby
class ContextualPrompt < LlmConductor::Prompts::BasePrompt
  def render
    [
      context_section,
      main_analysis_section,
      specific_questions_section,
      output_requirements_section
    ].join("\n\n")
  end

  private

  def context_section
    context_type = determine_context_type
    
    case context_type
    when :startup
      startup_context
    when :enterprise
      enterprise_context
    when :nonprofit
      nonprofit_context
    else
      generic_context
    end
  end

  def determine_context_type
    return :startup if founded_year && (Time.current.year - founded_year.to_i) < 5
    return :enterprise if employee_count && employee_count.to_i > 1000
    return :nonprofit if industry&.downcase&.include?('nonprofit')
    :generic
  end

  def startup_context
    <<~CONTEXT
      STARTUP ANALYSIS CONTEXT:
      This is an early-stage company (founded #{founded_year}).
      Focus on growth potential, scalability, and market validation.
    CONTEXT
  end

  def enterprise_context
    <<~CONTEXT
      ENTERPRISE ANALYSIS CONTEXT:
      This is an established company with #{employee_count}+ employees.
      Focus on market position, operational efficiency, and competitive advantages.
    CONTEXT
  end

  def nonprofit_context
    <<~CONTEXT
      NONPROFIT ANALYSIS CONTEXT:
      This is a nonprofit organization.
      Focus on mission alignment, social impact, and sustainability.
    CONTEXT
  end

  def generic_context
    "GENERAL COMPANY ANALYSIS:"
  end

  def main_analysis_section
    <<~ANALYSIS
      Company Overview:
      #{company_summary}

      Key Data Points:
      #{bulleted_list(extract_key_metrics)}
    ANALYSIS
  end

  def company_summary
    summary_parts = []
    summary_parts << "#{name} operates in the #{industry} sector" if name && industry
    summary_parts << "serving #{target_market}" if target_market
    summary_parts << "with #{truncate_text(description, max_length: 100)}" if description
    
    summary_parts.join(', ') + "."
  end

  def extract_key_metrics
    metrics = []
    metrics << "Domain: #{domain_name}" if domain_name
    metrics << "Founded: #{founded_year}" if founded_year
    metrics << "Employees: #{employee_count}" if employee_count
    metrics << "Revenue: #{revenue}" if revenue
    metrics.any? ? metrics : ["Limited public information available"]
  end

  def specific_questions_section
    questions = case determine_context_type
                when :startup
                  startup_questions
                when :enterprise
                  enterprise_questions
                when :nonprofit
                  nonprofit_questions
                else
                  generic_questions
                end

    "Specific Analysis Questions:\n#{numbered_list(questions)}"
  end

  def startup_questions
    [
      "What is the product-market fit and validation evidence?",
      "How scalable is the current business model?",
      "What are the main growth drivers and barriers?"
    ]
  end

  def enterprise_questions
    [
      "What are the key competitive advantages?",
      "How does the company maintain market leadership?",
      "What are the operational efficiency opportunities?"
    ]
  end

  def nonprofit_questions
    [
      "How effectively does the organization fulfill its mission?",
      "What is the sustainability of current funding model?",
      "How measurable is the social impact?"
    ]
  end

  def generic_questions
    [
      "What is the core business model?",
      "Who is the target market?",
      "What are the growth opportunities?"
    ]
  end

  def output_requirements_section
    <<~REQUIREMENTS
      Output Format:
      Please provide a structured analysis addressing all questions above.
      Use clear headings and bullet points for readability.
      Include specific recommendations where applicable.
    REQUIREMENTS
  end
end
```

## Testing Prompts

Prompts can be tested independently of LLM calls:

### Unit Testing

```ruby
# spec/prompts/company_analysis_prompt_spec.rb
RSpec.describe CompanyAnalysisPrompt do
  subject(:prompt) { described_class.new(data) }

  let(:data) do
    {
      name: 'TechCorp',
      domain_name: 'techcorp.com',
      description: 'A' * 1000, # Long description to test truncation
      industry: 'Technology'
    }
  end

  describe '#render' do
    it 'includes company name' do
      expect(prompt.render).to include('TechCorp')
    end

    it 'truncates long descriptions' do
      result = prompt.render
      expect(result).not_to include('A' * 1000)
      expect(result).to include('A' * 500) # Should be truncated to 500 chars
    end

    it 'includes analysis questions' do
      result = prompt.render
      expect(result).to include('Business model')
      expect(result).to include('Target market')
    end
  end

  describe 'with missing data' do
    let(:data) { { name: 'TechCorp' } }

    it 'handles missing fields gracefully' do
      expect { prompt.render }.not_to raise_error
    end
  end
end
```

### Integration Testing

```ruby
# spec/prompts/prompt_manager_integration_spec.rb
RSpec.describe 'Prompt Manager Integration' do
  before do
    LlmConductor::PromptManager.register(:test_prompt, CompanyAnalysisPrompt)
  end

  after do
    LlmConductor::PromptManager.unregister(:test_prompt)
  end

  it 'renders registered prompts' do
    result = LlmConductor::PromptManager.render(:test_prompt, { name: 'Test Co' })
    expect(result).to include('Test Co')
  end

  it 'integrates with LlmConductor.generate' do
    # Mock the LLM call
    allow_any_instance_of(LlmConductor::Clients::BaseClient).to receive(:generate_content)
      .and_return('Mock response')

    response = LlmConductor.generate(
      model: 'gpt-3.5-turbo',
      type: :test_prompt,
      data: { name: 'Test Co' }
    )

    expect(response).to be_a(LlmConductor::Response)
    expect(response.output).to eq('Mock response')
  end
end
```

## Best Practices

### 1. Prompt Organization

```ruby
# Organize prompts by domain
module CompanyPrompts
  class AnalysisPrompt < LlmConductor::Prompts::BasePrompt
    # Implementation
  end
  
  class SummaryPrompt < LlmConductor::Prompts::BasePrompt
    # Implementation
  end
end

# Register with namespace
LlmConductor::PromptManager.register(:company_analysis, CompanyPrompts::AnalysisPrompt)
LlmConductor::PromptManager.register(:company_summary, CompanyPrompts::SummaryPrompt)
```

### 2. Error Handling

```ruby
class SafePrompt < LlmConductor::Prompts::BasePrompt
  def render
    validate_data
    build_prompt
  rescue => e
    Rails.logger.error "Prompt generation error: #{e.message}"
    fallback_prompt
  end

  private

  def validate_data
    raise ArgumentError, "Name is required" unless name&.present?
    raise ArgumentError, "Description too long" if description&.length&.> 2000
  end

  def build_prompt
    # Main prompt logic
  end

  def fallback_prompt
    "Analyze the company #{name || 'Unknown Company'}."
  end
end
```

### 3. Configuration

```ruby
# config/initializers/llm_conductor_prompts.rb
Rails.application.config.after_initialize do
  # Register all company prompts
  {
    company_analysis: CompanyAnalysisPrompt,
    technical_analysis: TechnicalAnalysisPrompt,
    market_analysis: MarketAnalysisPrompt
  }.each do |type, klass|
    LlmConductor::PromptManager.register(type, klass)
  end

  Rails.logger.info "Registered #{LlmConductor::PromptManager.types.count} prompt types"
end
```

### 4. Performance Optimization

```ruby
class OptimizedPrompt < LlmConductor::Prompts::BasePrompt
  def render
    @rendered ||= build_optimized_prompt
  end

  private

  def build_optimized_prompt
    # Cache expensive operations
    @formatted_description ||= format_description
    @company_metrics ||= calculate_metrics

    <<~PROMPT
      #{@formatted_description}
      #{@company_metrics}
    PROMPT
  end

  def format_description
    return "No description available" unless description
    
    # Expensive formatting operation
    truncate_text(description.strip.gsub(/\s+/, ' '), max_length: 500)
  end

  def calculate_metrics
    # Expensive calculation
    return "No metrics available" unless respond_to?(:revenue) && revenue
    
    "Revenue: #{format_currency(revenue)}"
  end
end
```

This prompt registration system provides a powerful, flexible way to manage LLM prompts while maintaining clean, testable code. Use it to build reusable prompt libraries that can evolve with your application's needs.
