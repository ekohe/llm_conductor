# frozen_string_literal: true

# Patches the gemini-ai gem for two Vertex AI issues:
#
# 1. api_key + Vertex AI: the gem natively supports api_key only for
#    generative-language-api. When both project_id and api_key are present,
#    this patch rebuilds @base_address so the key is appended as ?key=... to
#    the correct Vertex AI endpoint.
#
# 2. ADC (Application Default Credentials): the gem calls
#    Google::Auth.get_application_default without a scope, which causes
#    `invalid_scope` when exchanging service-account credentials for a token.
#    This patch re-fetches the authorizer with the required cloud-platform scope.
module Gemini
  module Controllers
    class Client
      module VertexAiPatch
        CLOUD_PLATFORM_SCOPE = 'https://www.googleapis.com/auth/cloud-platform'

        def initialize(config)
          super
          fix_vertex_api_key_base_address(config) if @authentication == :api_key && @service == 'vertex-ai-api'
          fix_adc_scope if @authentication == :default_credentials
        end

        private

        def fix_vertex_api_key_base_address(config)
          project_id = config.dig(:credentials, :project_id)

          if project_id.nil?
            raise Errors::MissingProjectIdError,
                  'project_id is required for vertex-ai-api with api_key'
          end

          region = config.dig(:credentials, :region) || 'global'
          @base_address = if region == 'global'
                            "https://aiplatform.googleapis.com/#{@service_version}/projects/#{project_id}/locations/#{region}"
                          else
                            "https://#{region}-aiplatform.googleapis.com/#{@service_version}/projects/#{project_id}/locations/#{region}"
                          end
        end

        def fix_adc_scope
          @authorizer = ::Google::Auth.get_application_default(CLOUD_PLATFORM_SCOPE)
        end
      end

      prepend VertexAiPatch
    end
  end
end
