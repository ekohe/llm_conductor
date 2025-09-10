# frozen_string_literal: true

module LlmConductor
  module Prompts
    class CompanyAnalysisPrompt < BasePrompt
      def render
        <<~PROMPT
          Given the company's name, domain, description, and a list of industry-related keywords,
          please summarize the company's core business and identify the three most relevant industries.
          Highlight the company's unique value proposition, its primary market focus,
          and any distinguishing features that set it apart within the identified industries.
          Be as objective as possible.

          Name: #{name}
          Domain Name: #{domain_name}
          Industry: #{industries}
          Description: #{truncate_text(description, max_length: 2000)}
        PROMPT
      end
    end

    class WebContentAnalysisPrompt < BasePrompt
      def render
        <<~PROMPT
          Extract useful information from the webpage including a domain, detailed description of what the company does, founding year, country, business model, product description and features, customers and partners, development stage, and social media links. Output will be JSON.

          You are tasked with extracting useful information about a company from a given webpage content. Your goal is to analyze the content and extract specific details about the company, its products, and its operations.

          You will be provided with raw HTML content in the following format:

          <html_content>
          #{truncate_text(htmls, max_length: 10000)}
          </html_content>

          Carefully read through the webpage content and extract the following information about the company:

          - Name (field name): The company's name
          - Domain name (field domain_name): The company's domain
          - Description (field description): A comprehensive explanation of what the company does
          - Country (field country): The company's country
          - Region (field region): The company's region
          - Location (field location): The company's location
          - Founding on (field founded_on): Which year the company was established
          - Business model (field business_model): How the company generates revenue
          - Product description (product_description): A brief overview of the company's main product(s) or service(s)
          - Product features (product_features): Key features or capabilities of the product(s) or service(s)
          - Customers and partners (field customers_and_partners): Notable clients or business partners
          - Development stage (field development_stage): The current phase of the company (e.g., startup, growth, established)
          - Social media links (field social_media_links): URLs to the company's social media profiles
            - instagram_url
            - linkedin_url
            - twitter_url

          If any of the above information is not available in the webpage content, use "Not available" as the value for that field.

          Present your findings in JSON format. Here's an example of the expected structure:

          #{format_json_example(example_output)}

          Remember to use only the information provided in the webpage content. Do not include any external information or make assumptions beyond what is explicitly stated or strongly implied in the given content.

          Present your final output in JSON format, enclosed within <json_output> tags.
        PROMPT
      end

      private

      def example_output
        {
          "name" => "AI-powered customer service",
          "domain_name" => "example.com",
          "description" => "XYZ Company develops AI chatbots that help businesses automate customer support...",
          "founding_on" => 2018,
          "country" => "United States",
          "region" => "SA",
          "location" => "SFO",
          "business_model" => "SaaS subscription",
          "product_description" => "AI-powered chatbot platform for customer service automation",
          "product_features" => ["Natural language processing", "Multi-language support", "Integration with CRM systems"],
          "customers_and_partners" => ["ABC Corp", "123 Industries", "Big Tech Co."],
          "development_stage" => "Growth",
          "social_media_links" => {
            "linkedin_url" => "https://www.linkedin.com/company/xyzcompany",
            "twitter_url" => "https://twitter.com/xyzcompany",
            "instagram_url" => "https://www.instagram.com/xyzcompany"
          }
        }
      end
    end

    class FeaturedLinksPrompt < BasePrompt
      def render
        <<~PROMPT
          You are an AI assistant tasked with analyzing a webpage's HTML content to extract the most valuable links. Your goal is to identify links related to features, products, solutions, pricing, and social media profiles, prioritizing those from the same domain as the current page. Here are your instructions:

          - You will be provided with the HTML content of the current page in the following format:
          <page_html>
          #{truncate_text(htmls, max_length: 15000)}
          </page_html>

          - Parse the HTML content and extract all hyperlinks (a href attributes). Pay special attention to links in the navigation menu, footer, and main content areas.

          - Filter and prioritize the extracted links based on the following criteria:
             a. The link must be from the same domain as the current URL.
             b. Prioritize links containing keywords such as "features", "products", "solutions", "pricing", "about", "contact", or similar variations.
             c. Include social media profile links (e.g., LinkedIn, Instagram, Twitter, Facebook) if available.
             d. Exclude links to login pages, search pages, or other utility pages.

          - Select the top 3 most valuable links based on the above criteria.

          - Format your output as a JSON array of strings, where each string is a full URL. Use the following format:
          ["https://example.com/about-us", "https://example.com/products", "https://example.com/services"]

          - The links must be the same domain of following:
          <domain>
            #{current_url}
          </domain>

          If fewer than 3 relevant links are found, include only the available links in the output array.

          Remember to use the full URL for each link, including the domain name. If you encounter relative URLs, combine them with the domain from the current URL to create absolute URLs.

          Provide your final output without any additional explanation or commentary.
        PROMPT
      end
    end
  end
end
