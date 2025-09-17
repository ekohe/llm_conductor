#!/usr/bin/env ruby
# frozen_string_literal: true

# Example of the new prompt registration system
require_relative '../lib/llm_conductor'

# Configure the gem
LlmConductor.configure do |config|
  config.default_model = 'gpt-3.5-turbo'
  config.openai(api_key: ENV['OPENAI_API_KEY'])
end

# Define a custom prompt class
class CompanyAnalysisPrompt < LlmConductor::Prompts::BasePrompt
  def render
    <<~PROMPT
      Company: #{name}
      Domain: #{domain_name}
      Description: #{truncate_text(description, max_length: 1000)}

      Please analyze this company and provide:
      1. Core business model
      2. Target market
      3. Competitive advantages
      4. Growth potential

      Format as JSON with the following structure:
      {
        "business_model": "description",
        "target_market": "description",#{' '}
        "competitive_advantages": ["advantage1", "advantage2"],
        "growth_potential": "high|medium|low"
      }
    PROMPT
  end
end

# Define another prompt for summarization
class CompanySummaryPrompt < LlmConductor::Prompts::BasePrompt
  def render
    <<~PROMPT
      Company Information:
      #{company_details}

      Please provide a brief summary of this company in #{word_limit || 100} words or less.
      Focus on:
      #{bulleted_list(focus_areas || ['Main business', 'Key products/services', 'Market position'])}
    PROMPT
  end

  private

  def company_details
    details = []
    details << "Name: #{name}" if name
    details << "Domain: #{domain_name}" if domain_name
    details << "Description: #{description}" if description
    details << "Industry: #{industry}" if industry
    details.join("\n")
  end
end

# Register the prompt classes
LlmConductor::PromptManager.register(:detailed_analysis, CompanyAnalysisPrompt)
LlmConductor::PromptManager.register(:company_summary, CompanySummaryPrompt)

# Example company data
company_data = {
  name: 'TechCorp',
  domain_name: 'techcorp.com',
  description: 'A leading technology company specializing in artificial intelligence and machine learning ' \
               'solutions for enterprise clients. We help businesses automate their processes and make ' \
               'data-driven decisions through our cutting-edge AI platform.',
  industry: 'Technology',
  founded_year: 2020
}

puts '=== Example 1: Detailed Analysis ==='

# Use the registered prompt
response = LlmConductor.generate(
  model: 'gpt-3.5-turbo',
  data: company_data,
  type: :detailed_analysis
)

puts 'Generated Prompt Preview:'
puts LlmConductor::PromptManager.render(:detailed_analysis, company_data)
puts "\n#{'=' * 50}\n"

if response.success?
  puts "Response: #{response.output}"

  # Try to parse as JSON
  begin
    analysis = response.parse_json
    puts "\nParsed Analysis:"
    puts "Business Model: #{analysis['business_model']}"
    puts "Target Market: #{analysis['target_market']}"
    puts "Growth Potential: #{analysis['growth_potential']}"
  rescue JSON::ParserError => e
    puts "Note: Response is not valid JSON: #{e.message}"
  end
else
  puts "Error: #{response.metadata[:error]}"
end

puts "\n=== Example 2: Company Summary ==="

# Use the summary prompt with custom parameters
summary_data = company_data.merge(
  word_limit: 50,
  focus_areas: ['AI capabilities', 'Client base', 'Innovation']
)

response = LlmConductor.generate(
  model: 'gpt-3.5-turbo',
  data: summary_data,
  type: :company_summary
)

puts 'Generated Prompt Preview:'
puts LlmConductor::PromptManager.render(:company_summary, summary_data)
puts "\n#{'=' * 50}\n"

if response.success?
  puts "Summary: #{response.output}"
else
  puts "Error: #{response.metadata[:error]}"
end

puts "\n=== Available Prompt Types ==="
puts "Registered types: #{LlmConductor::PromptManager.types.join(', ')}"
