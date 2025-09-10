# frozen_string_literal: true

module LlmConductor
  module DataBuilders
    class CompanyDataBuilder < DataBuilder
      def build
        return {} unless source_object

        {
          id: safe_extract(:id),
          name: safe_extract(:name),
          domain_name: safe_extract(:domain_name),
          location: safe_extract(:location),
          description: safe_extract(:description),
          **company_data_fields,
          **company_statistics_fields
        }.compact
      end

      private

      def company_data_fields
        data_hash = safe_extract(:data, default: {})
        
        {
          industries: format_for_llm(data_hash['categories']),
          founded_year: data_hash['founded_on'],
          employee_count: data_hash['employee_count'],
          global_visits: data_hash['similarweb_visits']
        }.compact
      end

      def company_statistics_fields
        statistics_hash = safe_extract(:statistics, default: {})
        
        {
          employee_growth: statistics_hash['employee_counts_quarterly_growth_yoy'],
          visit_growth: statistics_hash['visits_3m_avg_growth_yoy']
        }.compact
      end
    end

    class WebContentDataBuilder < DataBuilder
      def build
        {
          htmls: format_html_content,
          current_url: safe_extract(:current_url),
          domain: extract_domain
        }
      end

      private

      def format_html_content
        html_content = safe_extract(:documents) || safe_extract(:htmls)
        
        case html_content
        when Array
          html_content.compact.join("\n\n")
        when String
          html_content
        else
          html_content.to_s
        end
      end

      def extract_domain
        url = safe_extract(:current_url)
        return nil unless url
        
        URI.parse(url).host
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
