# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Prompt Registration Integration' do
  # Sample prompt classes for testing
  class CompanyAnalysisPrompt < LlmConductor::Prompts::BasePrompt
    def render
      <<~PROMPT
        Company: #{name}
        Domain: #{domain_name}
        Description: #{truncate_text(description, max_length: 100)}

        Please analyze this company and provide:
        1. Core business model
        2. Target market
        3. Competitive advantages
        4. Growth potential

        Format as JSON.
      PROMPT
    end
  end

  class SimpleSummaryPrompt < LlmConductor::Prompts::BasePrompt
    def render
      "Summarize: #{respond_to?(:content) ? content : ''}"
    end
  end

  let(:company_data) do
    {
      name: 'TechCorp',
      domain_name: 'techcorp.com',
      description: 'A technology company specializing in AI solutions for businesses' * 5 # Make it long
    }
  end

  let(:mock_client) { instance_double(LlmConductor::Clients::GptClient) }

  before do
    # Clear any existing registrations
    LlmConductor::PromptManager.clear!

    # Register test prompts
    LlmConductor::PromptManager.register(:detailed_analysis, CompanyAnalysisPrompt)
    LlmConductor::PromptManager.register(:simple_summary, SimpleSummaryPrompt)

    # Mock client creation
    allow(LlmConductor).to receive(:build_client).and_return(mock_client)
  end

  after do
    LlmConductor::PromptManager.clear!
  end

  describe 'end-to-end prompt registration workflow' do
    it 'generates content using registered prompt class' do
      # Mock the client response
      mock_response = {
        input: 'Company: TechCorp...',
        output: '{"business_model": "SaaS", "target_market": "Enterprise"}',
        input_tokens: 50,
        output_tokens: 30
      }

      allow(mock_client).to receive(:generate).and_return(mock_response)

      # Generate using the registered prompt
      response = LlmConductor.generate(
        model: 'gpt-4',
        data: company_data,
        type: :detailed_analysis
      )

      # Verify the mock was called with the correct generated prompt
      expect(mock_client).to have_received(:generate) do |args|
        generated_prompt = args[:data]
        expect(generated_prompt).to be_a(Hash)
        expect(generated_prompt[:name]).to eq('TechCorp')
        expect(generated_prompt[:domain_name]).to eq('techcorp.com')
      end

      expect(response[:output]).to eq('{"business_model": "SaaS", "target_market": "Enterprise"}')
    end

    it 'falls back to legacy prompt methods for unregistered types' do
      # Mock legacy prompt method
      allow(mock_client).to receive(:send).with(:prompt_legacy_type, company_data)
                                          .and_return('Legacy prompt content')
      allow(mock_client).to receive(:generate).and_return({
                                                            input: 'Legacy prompt content',
                                                            output: 'Legacy response',
                                                            input_tokens: 20,
                                                            output_tokens: 15
                                                          })

      # This should fall back to the legacy method since it's not registered
      response = LlmConductor.generate(
        model: 'gpt-4',
        data: company_data,
        type: :legacy_type
      )

      expect(response[:output]).to eq('Legacy response')
    end
  end

  describe 'prompt rendering and data access' do
    it 'correctly renders prompt with data access methods' do
      prompt = CompanyAnalysisPrompt.new(company_data)
      rendered = prompt.render

      expect(rendered).to include('Company: TechCorp')
      expect(rendered).to include('Domain: techcorp.com')
      expect(rendered).to include('A technology company specializing in AI solutions')
      expect(rendered.length).to be < company_data[:description].length # Should be truncated
    end

    it 'provides direct access to PromptManager rendering' do
      rendered = LlmConductor::PromptManager.render(:detailed_analysis, company_data)

      expect(rendered).to include('Company: TechCorp')
      expect(rendered).to include('Domain: techcorp.com')
    end
  end

  describe 'error handling' do
    it 'raises appropriate error for unregistered prompt types' do
      expect do
        LlmConductor::PromptManager.create(:non_existent_type, company_data)
      end.to raise_error(LlmConductor::PromptManager::PromptNotFoundError,
                         'Prompt type :non_existent_type not found')
    end

    it 'handles data access errors gracefully in prompts' do
      prompt = SimpleSummaryPrompt.new({ not_content: 'wrong key' })

      # Should not raise error, just return empty string for missing method
      expect { prompt.render }.not_to raise_error
      expect(prompt.render).to eq('Summarize: ')
    end
  end

  describe 'prompt manager utility methods' do
    it 'lists all registered prompt types' do
      types = LlmConductor::PromptManager.types
      expect(types).to contain_exactly(:detailed_analysis, :simple_summary)
    end

    it 'checks if prompt types are registered' do
      expect(LlmConductor::PromptManager.registered?(:detailed_analysis)).to be true
      expect(LlmConductor::PromptManager.registered?(:non_existent)).to be false
    end

    it 'allows unregistering prompt types' do
      expect(LlmConductor::PromptManager.registered?(:simple_summary)).to be true

      LlmConductor::PromptManager.unregister(:simple_summary)

      expect(LlmConductor::PromptManager.registered?(:simple_summary)).to be false
      expect(LlmConductor::PromptManager.types).not_to include(:simple_summary)
    end
  end

  describe 'BaseClient integration' do
    let(:base_client) do
      LlmConductor::Clients::BaseClient.new(model: 'gpt-4', type: :detailed_analysis)
    end

    it 'uses PromptManager for registered prompt types' do
      # The build_prompt method should use PromptManager
      result = base_client.send(:build_prompt, company_data)

      expect(result).to include('Company: TechCorp')
      expect(result).to include('Format as JSON.')
    end

    it 'falls back to legacy methods for unregistered types' do
      unregistered_client = LlmConductor::Clients::BaseClient.new(
        model: 'gpt-4',
        type: :custom # This exists in Prompts module but isn't registered
      )

      # Mock the legacy prompt method
      allow(unregistered_client).to receive(:prompt_custom)
        .with(company_data)
        .and_return('legacy prompt')

      result = unregistered_client.send(:build_prompt, company_data)
      expect(result).to eq('legacy prompt')
    end
  end
end
