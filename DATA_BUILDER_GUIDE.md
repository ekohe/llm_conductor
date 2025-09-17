# Data Builder Pattern Guide

The LLM Conductor gem provides a powerful `DataBuilder` pattern for structuring complex data objects into clean, LLM-friendly formats. This guide covers the data builder system, helper methods, and best practices.

## Overview

The `DataBuilder` pattern solves common challenges when preparing data for LLM consumption:
- **Complex Object Structures** - Transform nested Rails models into flat, readable data
- **Data Sanitization** - Clean and format data for optimal LLM processing  
- **Consistent Formatting** - Standardize data presentation across different models
- **Null Safety** - Handle missing or invalid data gracefully
- **Reusable Logic** - Share data transformation logic across different prompts

## Quick Start

### 1. Create a DataBuilder Class

```ruby
class CompanyDataBuilder < LlmConductor::DataBuilder
  def build
    {
      id: source_object.id,
      name: safe_extract(:name),
      description: format_for_llm(safe_extract(:description), max_length: 500),
      industry: extract_nested_data(:data, 'categories', 'primary'),
      metrics: build_metrics,
      summary: build_company_summary
    }
  end

  private

  def build_metrics
    {
      employees: format_number(safe_extract(:employee_count)),
      revenue: format_currency(safe_extract(:revenue)),
      founded: safe_extract(:founded_year, default: 'Unknown')
    }
  end

  def build_company_summary
    name = safe_extract(:name, default: 'Company')
    industry = extract_nested_data(:data, 'categories', 'primary') || 'Unknown'
    "#{name} is a #{industry} company."
  end

  def format_currency(amount)
    return 'Not disclosed' unless amount
    "$#{format_number(amount)}"
  end
end
```

### 2. Use the DataBuilder

```ruby
# With a Rails model
company = Company.find(123)
data = CompanyDataBuilder.new(company).build

# Use with LLM generation
response = LlmConductor.generate(
  model: 'gpt-4',
  type: :company_analysis,
  data: data
)
```

## Base DataBuilder Class

All data builders inherit from `LlmConductor::DataBuilder`:

```ruby
class MyDataBuilder < LlmConductor::DataBuilder
  def initialize(source_object)
    @source_object = source_object
  end

  def build
    # Must be implemented by subclasses
    raise NotImplementedError
  end

  protected

  attr_reader :source_object
end
```

## Built-in Helper Methods

### Data Extraction

#### `safe_extract(key, options = {})`
Safely extracts data with fallbacks and type coercion:

```ruby
class ExampleBuilder < LlmConductor::DataBuilder
  def build
    {
      # Basic extraction
      name: safe_extract(:name),
      
      # With default value
      industry: safe_extract(:industry, default: 'Unknown'),
      
      # With type coercion
      employee_count: safe_extract(:employee_count, type: :integer),
      founded_year: safe_extract(:founded_year, type: :integer),
      is_public: safe_extract(:is_public, type: :boolean),
      
      # With validation
      email: safe_extract(:email, validate: :email),
      url: safe_extract(:website, validate: :url)
    }
  end
end

# Handles missing data gracefully
company = OpenStruct.new(name: 'TechCorp')  # Missing other fields
data = ExampleBuilder.new(company).build
# => { name: 'TechCorp', industry: 'Unknown', employee_count: nil, ... }
```

#### `extract_nested_data(*path)`
Navigates nested data structures safely:

```ruby
def build
  {
    # Extract from nested hashes
    primary_industry: extract_nested_data(:data, 'categories', 'primary'),
    
    # Extract from arrays
    first_funding_round: extract_nested_data(:funding, 0, 'amount'),
    
    # Extract with mixed types
    office_city: extract_nested_data(:locations, 'headquarters', :city),
    
    # Returns nil for missing paths
    missing_data: extract_nested_data(:non, :existent, :path)
  }
end

# Example source object:
# {
#   data: {
#     'categories' => { 'primary' => 'Technology', 'secondary' => 'AI' }
#   },
#   funding: [
#     { 'amount' => 1000000, 'round' => 'Seed' }
#   ],
#   locations: {
#     'headquarters' => { city: 'San Francisco', country: 'USA' }
#   }
# }
```

### Data Formatting

#### `format_for_llm(text, options = {})`
Optimizes text for LLM consumption:

```ruby
def build
  {
    # Basic formatting (removes extra whitespace, normalizes)
    description: format_for_llm(source_object.description),
    
    # With length limits
    short_bio: format_for_llm(source_object.bio, max_length: 200),
    
    # With custom defaults
    mission: format_for_llm(
      source_object.mission, 
      max_length: 300,
      default: 'Mission not specified'
    )
  }
end
```

#### `format_number(value, options = {})`
Formats numbers for readability:

```ruby
def build
  {
    # Basic number formatting (adds commas)
    employees: format_number(source_object.employee_count),
    # => "1,234" or "50,000,000"
    
    # With precision for decimals
    growth_rate: format_number(source_object.growth_rate, precision: 2),
    # => "15.75" or "125.50"
    
    # With custom defaults
    revenue: format_number(
      source_object.revenue, 
      default: 'Not disclosed',
      prefix: '$'
    ),
    # => "$50,000,000" or "Not disclosed"
    
    # As percentages
    market_share: format_number(
      source_object.market_share,
      as_percentage: true,
      precision: 1
    )
    # => "15.5%" or "0.8%"
  }
end
```

### Data Validation

#### `validate_data(validations = {})`
Validates data structure and content:

```ruby
class ValidatedBuilder < LlmConductor::DataBuilder
  def build
    validate_data(
      name: { presence: true, type: String },
      employee_count: { type: Integer, minimum: 1 },
      email: { format: :email },
      website: { format: :url }
    )

    {
      name: safe_extract(:name),
      employee_count: safe_extract(:employee_count),
      email: safe_extract(:email),
      website: safe_extract(:website)
    }
  end
end
```

#### `has_attribute?(attribute)`
Checks if the source object has a specific attribute:

```ruby
def build
  data = { id: source_object.id }
  
  # Conditional data inclusion
  data[:name] = safe_extract(:name) if has_attribute?(:name)
  data[:description] = safe_extract(:description) if has_attribute?(:description)
  data[:metrics] = build_metrics if has_metrics_data?
  
  data
end

private

def has_metrics_data?
  has_attribute?(:employee_count) || 
  has_attribute?(:revenue) || 
  has_attribute?(:founded_year)
end
```

## Advanced Patterns

### 1. Compositional Data Building

Break complex data building into smaller, focused methods:

```ruby
class ComplexCompanyBuilder < LlmConductor::DataBuilder
  def build
    {
      **basic_info,
      **business_metrics,
      **financial_data,
      **social_presence,
      summary: build_summary
    }
  end

  private

  def basic_info
    {
      id: source_object.id,
      name: safe_extract(:name),
      domain: safe_extract(:domain_name),
      industry: extract_nested_data(:data, 'categories', 'primary'),
      founded: safe_extract(:founded_year, type: :integer)
    }
  end

  def business_metrics
    {
      employee_count: format_number(safe_extract(:employee_count)),
      office_locations: extract_office_locations,
      key_technologies: extract_list(:technologies, limit: 5)
    }
  end

  def financial_data
    return {} unless has_financial_data?

    {
      revenue: format_currency(safe_extract(:revenue)),
      funding_total: format_currency(extract_nested_data(:funding, 'total')),
      last_funding_round: extract_nested_data(:funding, 'rounds', -1, 'type')
    }
  end

  def social_presence
    {
      linkedin_url: safe_extract(:linkedin_url, validate: :url),
      twitter_handle: safe_extract(:twitter_handle),
      employee_growth: calculate_employee_growth
    }
  end

  def extract_office_locations
    locations = extract_nested_data(:locations) || []
    locations.map { |loc| "#{loc['city']}, #{loc['country']}" }
             .join('; ')
  end

  def has_financial_data?
    has_attribute?(:revenue) || 
    extract_nested_data(:funding).present?
  end

  def calculate_employee_growth
    current = safe_extract(:employee_count, type: :integer)
    previous = extract_nested_data(:employee_history, -2, 'count')
    
    return 'No data' unless current && previous
    
    growth = ((current - previous) / previous.to_f * 100).round(1)
    "#{growth > 0 ? '+' : ''}#{growth}%"
  end

  def build_summary
    parts = []
    parts << "#{safe_extract(:name)} is a #{extract_nested_data(:data, 'categories', 'primary')} company"
    parts << "founded in #{safe_extract(:founded_year)}" if safe_extract(:founded_year)
    parts << "with #{format_number(safe_extract(:employee_count))} employees" if safe_extract(:employee_count)
    
    parts.join(' ') + '.'
  end
end
```

### 2. Conditional Data Transformation

Transform data based on the source object's characteristics:

```ruby
class AdaptiveCompanyBuilder < LlmConductor::DataBuilder
  def build
    base_data.merge(stage_specific_data).merge(industry_specific_data)
  end

  private

  def base_data
    {
      name: safe_extract(:name),
      description: format_for_llm(safe_extract(:description), max_length: base_description_length),
      industry: extract_nested_data(:data, 'categories', 'primary')
    }
  end

  def stage_specific_data
    case company_stage
    when :startup
      startup_data
    when :growth
      growth_stage_data
    when :enterprise
      enterprise_data
    else
      {}
    end
  end

  def industry_specific_data
    case extract_nested_data(:data, 'categories', 'primary')&.downcase
    when 'technology', 'software'
      tech_company_data
    when 'finance', 'fintech'
      finance_company_data
    when 'healthcare', 'biotech'
      healthcare_company_data
    else
      {}
    end
  end

  def startup_data
    {
      stage: 'Startup',
      founded_year: safe_extract(:founded_year),
      funding_raised: format_currency(extract_nested_data(:funding, 'total')),
      key_investors: extract_list(extract_nested_data(:funding, 'investors'), limit: 3)
    }
  end

  def growth_stage_data
    {
      stage: 'Growth',
      employee_growth: calculate_growth_metrics(:employee_count),
      revenue_growth: calculate_growth_metrics(:revenue),
      market_expansion: extract_market_data
    }
  end

  def enterprise_data
    {
      stage: 'Enterprise',
      market_position: safe_extract(:market_position),
      global_presence: extract_global_metrics,
      key_partnerships: extract_list(:partnerships, limit: 5)
    }
  end

  def tech_company_data
    {
      technology_stack: extract_list(:technologies, limit: 8),
      github_activity: extract_nested_data(:social, 'github', 'activity'),
      engineering_culture: safe_extract(:engineering_culture)
    }
  end

  def company_stage
    employee_count = safe_extract(:employee_count, type: :integer) || 0
    founded_year = safe_extract(:founded_year, type: :integer)
    years_in_business = founded_year ? Time.current.year - founded_year : 0

    return :startup if employee_count < 50 && years_in_business < 5
    return :enterprise if employee_count > 1000 || years_in_business > 15
    :growth
  end

  def base_description_length
    case company_stage
    when :startup then 300
    when :growth then 500  
    when :enterprise then 400
    else 250
    end
  end
end
```

### 3. Data Builder Inheritance

Create hierarchies of builders for different use cases:

```ruby
# Base builder for all company data
class BaseCompanyBuilder < LlmConductor::DataBuilder
  protected

  def company_essentials
    {
      id: source_object.id,
      name: safe_extract(:name),
      domain: safe_extract(:domain_name),
      industry: primary_industry
    }
  end

  def primary_industry
    extract_nested_data(:data, 'categories', 'primary') || 'Unknown'
  end

  def format_employee_count(count = nil)
    count ||= safe_extract(:employee_count)
    return 'Not specified' unless count
    
    case count.to_i
    when 0..10 then '1-10 employees'
    when 11..50 then '11-50 employees'  
    when 51..200 then '51-200 employees'
    when 201..1000 then '201-1000 employees'
    else '1000+ employees'
    end
  end
end

# Specialized for analysis prompts
class AnalysisCompanyBuilder < BaseCompanyBuilder
  def build
    {
      **company_essentials,
      description: format_for_llm(safe_extract(:description), max_length: 600),
      key_metrics: analysis_metrics,
      competitive_context: competitive_data,
      growth_indicators: growth_data
    }
  end

  private

  def analysis_metrics
    {
      employee_range: format_employee_count,
      revenue_range: format_revenue_range,
      funding_stage: extract_nested_data(:funding, 'stage'),
      market_presence: calculate_market_presence_score
    }
  end

  def competitive_data
    competitors = extract_list(:competitors, limit: 5)
    return 'No competitive data' if competitors.empty?
    
    "Main competitors: #{competitors.join(', ')}"
  end

  def growth_data
    indicators = []
    indicators << "Employee growth: #{calculate_employee_growth}" if has_employee_data?
    indicators << "Funding growth: #{calculate_funding_growth}" if has_funding_data?
    indicators << "Market expansion: #{extract_market_expansion}" if has_market_data?
    
    indicators.any? ? indicators : ['Limited growth data available']
  end
end

# Specialized for summary prompts
class SummaryCompanyBuilder < BaseCompanyBuilder
  def build
    {
      **company_essentials,
      description: format_for_llm(safe_extract(:description), max_length: 200),
      key_facts: summary_facts,
      notable_achievements: extract_achievements
    }
  end

  private

  def summary_facts
    facts = []
    facts << "Founded in #{safe_extract(:founded_year)}" if safe_extract(:founded_year)
    facts << format_employee_count if safe_extract(:employee_count)
    facts << "Raised #{format_currency(extract_nested_data(:funding, 'total'))}" if extract_nested_data(:funding, 'total')
    
    facts.any? ? facts : ['Limited company information available']
  end

  def extract_achievements
    achievements = extract_list(:achievements, limit: 3)
    awards = extract_list(:awards, limit: 2)
    
    (achievements + awards).take(3)
  end
end
```

### 4. Data Builder Composition

Combine multiple data sources:

```ruby
class CompositeCompanyBuilder < LlmConductor::DataBuilder
  def initialize(company, external_data = {})
    super(company)
    @external_data = external_data
  end

  def build
    {
      **internal_company_data,
      **external_enrichment_data,
      **computed_insights,
      data_sources: data_source_summary
    }
  end

  private

  attr_reader :external_data

  def internal_company_data
    {
      name: safe_extract(:name),
      description: format_for_llm(safe_extract(:description), max_length: 400),
      industry: extract_nested_data(:data, 'categories', 'primary'),
      employee_count: safe_extract(:employee_count)
    }
  end

  def external_enrichment_data
    return {} if external_data.empty?

    {
      market_data: extract_from_external(:market_analysis),
      social_sentiment: extract_from_external(:social_sentiment),
      news_mentions: extract_from_external(:recent_news, limit: 3),
      competitor_analysis: extract_from_external(:competitor_data)
    }
  end

  def computed_insights
    {
      growth_potential: assess_growth_potential,
      market_opportunity: assess_market_opportunity,
      risk_factors: identify_risk_factors,
      investment_signals: extract_investment_signals
    }
  end

  def extract_from_external(key, options = {})
    data = external_data[key]
    return nil unless data

    if options[:limit] && data.is_a?(Array)
      data.take(options[:limit])
    else
      data
    end
  end

  def assess_growth_potential
    factors = []
    factors << 'High employee growth' if employee_growth_rate > 0.2
    factors << 'Recent funding' if recent_funding?
    factors << 'Market expansion' if expanding_markets?
    
    score = factors.length
    { score: score, factors: factors }
  end

  def data_source_summary
    sources = ['Internal company database']
    sources << 'Market analysis API' if external_data[:market_analysis]
    sources << 'Social sentiment API' if external_data[:social_sentiment]
    sources << 'News aggregation' if external_data[:recent_news]
    
    sources
  end
end
```

## Testing Data Builders

### Unit Tests

```ruby
# spec/data_builders/company_data_builder_spec.rb
RSpec.describe CompanyDataBuilder do
  let(:company) do
    double(
      'Company',
      id: 123,
      name: 'TechCorp',
      description: 'An AI company' * 50, # Long description
      employee_count: 150,
      founded_year: 2020,
      data: { 'categories' => { 'primary' => 'Technology' } }
    )
  end

  subject(:builder) { described_class.new(company) }

  describe '#build' do
    let(:result) { builder.build }

    it 'includes basic company information' do
      expect(result[:name]).to eq('TechCorp')
      expect(result[:id]).to eq(123)
    end

    it 'formats description for LLM consumption' do
      expect(result[:description].length).to be <= 500
      expect(result[:description]).not_to be_empty
    end

    it 'extracts nested industry data' do
      expect(result[:industry]).to eq('Technology')
    end

    it 'formats employee count' do
      expect(result[:metrics][:employees]).to eq('150')
    end

    it 'generates company summary' do
      expect(result[:summary]).to include('TechCorp')
      expect(result[:summary]).to include('Technology')
    end

    context 'with missing data' do
      let(:company) { double('Company', id: 456, name: 'MissingCorp') }

      it 'handles missing fields gracefully' do
        expect(result[:name]).to eq('MissingCorp')
        expect(result[:industry]).to be_nil
        expect(result[:description]).to be_nil
      end
    end
  end
end
```

### Integration Tests

```ruby
# spec/integration/data_builder_llm_integration_spec.rb
RSpec.describe 'DataBuilder LLM Integration' do
  let(:company) { create(:company, :with_full_data) }
  let(:data_builder) { CompanyDataBuilder.new(company) }

  it 'integrates with LLM generation' do
    data = data_builder.build

    response = LlmConductor.generate(
      model: 'gpt-3.5-turbo',
      type: :company_analysis,
      data: data
    )

    expect(response.success?).to be true
    expect(response.output).to include(company.name)
  end

  it 'produces consistent data structure' do
    data = data_builder.build

    expect(data).to have_key(:name)
    expect(data).to have_key(:description)
    expect(data).to have_key(:metrics)
    expect(data).to have_key(:summary)
  end
end
```

## Best Practices

### 1. Null Safety First

Always handle missing or invalid data:

```ruby
def build
  {
    # Good - handles nil gracefully
    name: safe_extract(:name) || 'Unknown Company',
    
    # Bad - could raise error
    # name: source_object.name.upcase,
    
    # Good - safe navigation
    employee_count: safe_extract(:employee_count, type: :integer, default: 0),
    
    # Good - nested extraction with fallback
    industry: extract_nested_data(:data, 'categories', 'primary') || 
              extract_nested_data(:data, 'industry') ||
              'Unknown'
  }
end
```

### 2. Consistent Formatting

Use helper methods for consistent data formatting:

```ruby
def build
  {
    # Consistent number formatting
    employees: format_number(safe_extract(:employee_count)),
    revenue: format_number(safe_extract(:revenue), prefix: '$'),
    growth_rate: format_number(safe_extract(:growth_rate), as_percentage: true),
    
    # Consistent text formatting
    description: format_for_llm(safe_extract(:description), max_length: 400),
    mission: format_for_llm(safe_extract(:mission), max_length: 200),
    
    # Consistent list formatting
    technologies: extract_list(:technologies, limit: 8, separator: ', '),
    locations: extract_list(:office_locations, limit: 5)
  }
end
```

### 3. Performance Optimization

Cache expensive operations:

```ruby
class OptimizedDataBuilder < LlmConductor::DataBuilder
  def build
    {
      name: safe_extract(:name),
      description: formatted_description,
      metrics: calculated_metrics,
      summary: generated_summary
    }
  end

  private

  # Memoize expensive operations
  def formatted_description
    @formatted_description ||= format_for_llm(
      safe_extract(:description), 
      max_length: 500
    )
  end

  def calculated_metrics
    @calculated_metrics ||= {
      employee_range: format_employee_count,
      revenue_estimate: calculate_revenue_estimate,
      growth_score: calculate_growth_score
    }
  end

  def generated_summary
    @generated_summary ||= begin
      parts = [
        safe_extract(:name),
        "operates in #{primary_industry}",
        "with #{format_employee_count}"
      ]
      parts.compact.join(' ')
    end
  end
end
```

### 4. Documentation and Examples

Document your data builders with clear examples:

```ruby
# Transforms company objects into structured data for LLM analysis
#
# @example Basic usage
#   company = Company.find(123)
#   builder = CompanyAnalysisBuilder.new(company)
#   data = builder.build
#   # => {
#   #   name: "TechCorp",
#   #   industry: "Technology", 
#   #   metrics: { employees: "150", revenue: "$10,000,000" }
#   # }
#
# @example With external data
#   builder = EnrichedCompanyBuilder.new(company, market_data: api_data)
#   data = builder.build
#
class CompanyAnalysisBuilder < LlmConductor::DataBuilder
  # Returns structured company data optimized for LLM analysis
  #
  # @return [Hash] Formatted company data with:
  #   - :name [String] Company name
  #   - :industry [String] Primary industry classification
  #   - :description [String] Truncated, formatted description
  #   - :metrics [Hash] Key business metrics
  #   - :summary [String] Generated company summary
  def build
    # Implementation
  end
end
```

The Data Builder pattern provides a clean, maintainable way to transform complex objects into LLM-friendly data structures while handling edge cases and providing consistent formatting across your application.
