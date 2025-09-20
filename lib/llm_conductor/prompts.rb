# frozen_string_literal: true

module LlmConductor
  # Collection of general-purpose prompt templates for common LLM tasks
  module Prompts
    # General prompt for extracting links from HTML content
    # More flexible and applicable to various use cases
    def prompt_extract_links(data)
      criteria = data[:criteria] || "relevant and useful"
      max_links = data[:max_links] || 10
      link_types = data[:link_types] || ["navigation", "content", "footer"]
      
      <<~PROMPT
        Analyze the provided HTML content and extract links based on the specified criteria.

        HTML Content:
        #{data[:html_content] || data[:htmls]}

        Extraction Criteria: #{criteria}
        Maximum Links: #{max_links}
        Link Types to Consider: #{link_types.join(', ')}
        
        #{if data[:domain_filter]
          "Domain Filter: Only include links from domain #{data[:domain_filter]}"
        end}

        Instructions:
        1. Parse the HTML content and identify all hyperlinks
        2. Filter links based on the provided criteria
        3. Prioritize links from specified areas: #{link_types.join(', ')}
        4. Return up to #{max_links} most relevant links
        #{if data[:format] == :json
          "5. Format output as a JSON array of URLs"
        else
          "5. Format output as a newline-separated list of URLs"
        end}

        Provide only the links without additional commentary.
      PROMPT
    end

    # General prompt for content analysis and data extraction
    # Flexible template for various content analysis tasks
    def prompt_analyze_content(data)
      content_type = data[:content_type] || "webpage content"
      analysis_fields = data[:fields] || ["summary", "key_points", "entities"]
      output_format = data[:output_format] || "structured text"
      
      <<~PROMPT
        Analyze the provided #{content_type} and extract the requested information.

        Content:
        #{data[:content] || data[:htmls] || data[:text]}

        Analysis Fields:
        #{analysis_fields.map { |field| "- #{field}" }.join("\n")}

        #{if data[:instructions]
          "Additional Instructions:\n#{data[:instructions]}"
        end}

        #{if output_format == "json"
          "Output Format: JSON with the following structure:\n{\n" + 
          analysis_fields.map { |field| "  \"#{field}\": \"value or array\"" }.join(",\n") + 
          "\n}"
        else
          "Output Format: #{output_format}"
        end}

        #{if data[:constraints]
          "Constraints:\n#{data[:constraints]}"
        end}

        Provide a comprehensive analysis focusing on the requested fields.
      PROMPT
    end

    # General prompt for text summarization
    # Applicable to various types of text content
    def prompt_summarize_text(data)
      max_length = data[:max_length] || "200 words"
      focus_areas = data[:focus_areas] || []
      style = data[:style] || "concise and informative"
      
      <<~PROMPT
        Summarize the following text content.

        Text:
        #{data[:text] || data[:content] || data[:description]}

        Summary Requirements:
        - Maximum Length: #{max_length}
        - Style: #{style}
        #{if focus_areas.any?
          "- Focus Areas: #{focus_areas.join(', ')}"
        end}
        #{if data[:audience]
          "- Target Audience: #{data[:audience]}"
        end}

        #{if data[:include_key_points]
          "Include key points and main themes."
        end}
        
        #{if data[:output_format] == "bullet_points"
          "Format as bullet points."
        elsif data[:output_format] == "paragraph"
          "Format as a single paragraph."
        end}

        Provide a clear and accurate summary.
      PROMPT
    end

    # General prompt for data classification and categorization
    # Useful for various classification tasks
    def prompt_classify_content(data)
      categories = data[:categories] || []
      classification_type = data[:classification_type] || "content"
      confidence_scores = data[:include_confidence] || false
      
      <<~PROMPT
        Classify the provided #{classification_type} into the most appropriate category.

        Content to Classify:
        #{data[:content] || data[:text] || data[:description]}

        Available Categories:
        #{categories.map.with_index(1) { |cat, i| "#{i}. #{cat}" }.join("\n")}

        #{if data[:classification_criteria]
          "Classification Criteria:\n#{data[:classification_criteria]}"
        end}

        #{if confidence_scores
          "Output Format: JSON with category and confidence score (0-1)"
        else
          "Output Format: Return the most appropriate category name"
        end}

        #{if data[:multiple_categories]
          "Note: Multiple categories may apply - select up to #{data[:max_categories] || 3} most relevant."
        else
          "Note: Select only the single most appropriate category."
        end}

        Provide your classification based on the content analysis.
      PROMPT
    end

    # Flexible custom prompt template
    # Allows for dynamic prompt creation with variable substitution
    def prompt_custom(data)
      template = data.fetch(:template, "Please analyze the following content: %{content}")
      template % data
    end
  end
end
