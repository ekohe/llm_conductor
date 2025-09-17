# frozen_string_literal: true

require_relative '../lib/llm_conductor'

# Example: Company Data Builder
#
# This example demonstrates how to use LlmConductor::DataBuilder to structure
# data from complex objects for LLM consumption.

class CompanyDataBuilder < LlmConductor::DataBuilder
  def build
    {
      id: source_object.id,
      name: source_object.name,
      domain_name: source_object.domain_name,
      description: format_for_llm(source_object.description, max_length: 500),
      industry: extract_nested_data(:data, 'categories', 'primary') || 'Unknown',
      location: build_location,
      metrics: build_metrics,
      technology_stack: extract_list(:technologies, limit: 5, separator: ', '),
      summary: build_company_summary
    }
  end

  private

  def build_location
    city = safe_extract(:city, default: nil)
    country = safe_extract(:country, default: nil)

    return 'Unknown' if city.nil? && country.nil?
    return city if country.nil?
    return country if city.nil?

    "#{city}, #{country}"
  end

  def build_metrics
    {
      employees: format_employee_count,
      revenue: format_revenue,
      founded: safe_extract(:founded_year, default: 'Unknown'),
      funding: extract_nested_data(:financial_data, 'total_funding'),
      stage: extract_nested_data(:financial_data, 'stage')
    }
  end

  def format_employee_count
    count = safe_extract(:employee_count)
    return 'Unknown' if count.nil?

    case count
    when 0..10
      'Small (1-10)'
    when 11..50
      'Medium (11-50)'
    when 51..200
      'Large (51-200)'
    when 201..1000
      'Enterprise (201-1000)'
    else
      'Large Enterprise (1000+)'
    end
  end

  def format_revenue
    revenue = safe_extract(:revenue)
    return 'Not disclosed' if revenue.nil? || revenue.zero?

    format_number(revenue, as_currency: true, precision: 0)
  end

  def build_company_summary
    name = safe_extract(:name, default: 'Unknown Company')
    industry = extract_nested_data(:data, 'categories', 'primary') || 'Unknown Industry'
    employees = format_employee_count
    location = build_location

    "#{name} is a #{industry.downcase} company with #{employees.downcase} employees, " \
    "based in #{location}"
  end
end

# Example: User Profile Builder
class UserProfileBuilder < LlmConductor::DataBuilder
  def build
    {
      basic_info: build_basic_info,
      professional: build_professional_info,
      preferences: build_preferences,
      activity_summary: build_activity_summary
    }
  end

  private

  def build_basic_info
    {
      name: format_for_llm(build_full_name),
      email: safe_extract(:email, default: 'Not provided'),
      age: calculate_age,
      location: build_summary(:city, :state, :country, separator: ', ')
    }
  end

  def build_full_name
    first = safe_extract(:first_name, default: '')
    last = safe_extract(:last_name, default: '')
    "#{first} #{last}".strip
  end

  def calculate_age
    birth_date = safe_extract(:birth_date)
    return 'Unknown' if birth_date.nil?

    begin
      ((Time.zone.now - birth_date) / 365.25 / 24 / 60 / 60).to_i
    rescue StandardError
      'Unknown'
    end
  end

  def build_professional_info
    {
      title: safe_extract(:job_title, default: 'Not specified'),
      company: safe_extract(:company_name, default: 'Not specified'),
      experience_years: safe_extract(:years_experience, default: 'Unknown'),
      skills: extract_list(:skills, limit: 10, separator: ', '),
      industry: extract_nested_data(:profile, 'professional', 'industry')
    }
  end

  def build_preferences
    preferences = safe_extract(:preferences, default: {})
    return 'No preferences set' unless preferences.respond_to?(:[])

    {
      communication: preferences['communication'] || 'Email',
      notifications: preferences['notifications'] ? 'Enabled' : 'Disabled',
      privacy_level: preferences['privacy'] || 'Standard'
    }
  end

  def build_activity_summary
    summary_parts = []

    add_membership_info(summary_parts)
    add_activity_info(summary_parts)

    summary_parts.empty? ? 'No activity data' : summary_parts.join(' • ')
  end

  def add_membership_info(summary_parts)
    account_created = safe_extract(:created_at)
    return unless account_created

    formatted_date = format_creation_date(account_created)
    summary_parts << "Member since #{formatted_date}"
  end

  def add_activity_info(summary_parts)
    last_login = safe_extract(:last_login_at)
    return unless last_login

    days_ago = calculate_days_since_login(last_login)
    return unless days_ago

    summary_parts << format_activity_status(days_ago)
  end

  def format_creation_date(account_created)
    account_created.strftime('%B %Y')
  rescue StandardError
    'Unknown'
  end

  def calculate_days_since_login(last_login)
    ((Time.zone.now - last_login) / 86_400).to_i
  rescue StandardError
    nil
  end

  def format_activity_status(days_ago)
    case days_ago
    when 0
      'Active today'
    when 1
      'Last active yesterday'
    when 2..7
      "Last active #{days_ago} days ago"
    else
      'Inactive user'
    end
  end
end

# Example usage with mock data
puts '=== Company Data Builder Example ==='

# Mock company object
company_data = OpenStruct.new(
  id: 1,
  name: 'InnovateTech Solutions',
  domain_name: 'innovatetech.com',
  description: 'A cutting-edge technology company focused on AI and machine learning solutions ' \
               'for enterprise customers.',
  city: 'San Francisco',
  country: 'USA',
  employee_count: 150,
  revenue: 25_000_000,
  founded_year: 2018,
  technologies: %w[Ruby Python JavaScript AWS Docker Kubernetes],
  data: {
    'categories' => {
      'primary' => 'Software Development',
      'secondary' => 'AI/ML'
    }
  },
  financial_data: {
    'total_funding' => '$5.2M',
    'stage' => 'Series A'
  }
)

company_builder = CompanyDataBuilder.new(company_data)
company_result = company_builder.build

puts 'Company data structure:'
puts JSON.pretty_generate(company_result)

puts "\n=== Using with LLM Conductor ==="

# Example of using the built data with LLM Conductor
# response = LlmConductor.generate(
#   model: 'gpt-3.5-turbo',
#   data: company_result,
#   type: :company_analysis
# )

puts 'Built data ready for LLM consumption:'
puts "- Company: #{company_result[:name]}"
puts "- Industry: #{company_result[:industry]}"
puts "- Summary: #{company_result[:summary]}"

puts "\n=== User Profile Builder Example ==="

# Mock user object
user_data = OpenStruct.new(
  first_name: 'John',
  last_name: 'Doe',
  email: 'john.doe@example.com',
  birth_date: Time.zone.parse('1985-03-15'),
  city: 'Austin',
  state: 'Texas',
  country: 'USA',
  job_title: 'Senior Software Engineer',
  company_name: 'TechCorp',
  years_experience: 8,
  skills: %w[Ruby Rails JavaScript React PostgreSQL],
  created_at: Time.zone.parse('2020-01-15'),
  last_login_at: Time.zone.now - (2 * 24 * 60 * 60), # 2 days ago
  preferences: {
    'communication' => 'Email',
    'notifications' => true,
    'privacy' => 'High'
  },
  profile: {
    'professional' => {
      'industry' => 'Technology'
    }
  }
)

user_builder = UserProfileBuilder.new(user_data)
user_result = user_builder.build

puts 'User profile structure:'
puts JSON.pretty_generate(user_result)

puts "\n=== Error Handling Example ==="

# Example with missing/nil data
incomplete_company = OpenStruct.new(
  id: 2,
  name: 'StartupCorp',
  domain_name: nil,
  description: '',
  employee_count: nil,
  revenue: 0,
  city: 'New York'
  # Missing many other fields
)

incomplete_builder = CompanyDataBuilder.new(incomplete_company)
incomplete_result = incomplete_builder.build

puts 'Handling incomplete data:'
puts "- Revenue: #{incomplete_result[:metrics][:revenue]}"
puts "- Industry: #{incomplete_result[:industry]}"
puts "- Location: #{incomplete_result[:location]}"
puts "- Employee Count: #{incomplete_result[:metrics][:employees]}"
