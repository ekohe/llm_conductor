# frozen_string_literal: true

require_relative 'lib/llm_conductor/version'

Gem::Specification.new do |spec|
  spec.name = 'llm_conductor'
  spec.version = LlmConductor::VERSION
  spec.authors = ['Ben']
  spec.email = ['ben@example.com']
  spec.summary = 'Orchestrate multiple LLM services in Rails applications'
  spec.homepage = 'https://github.com/ben/llm_conductor'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4.1'
  
  spec.files = Dir['lib/**/*', 'README.md']
  spec.require_paths = ['lib']
  
  spec.add_dependency 'activesupport', '>= 6.0'
end
