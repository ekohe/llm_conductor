# frozen_string_literal: true

require_relative 'lib/llm_conductor/version'

Gem::Specification.new do |spec|
  spec.name = 'llm_conductor'
  spec.version = LlmConductor::VERSION
  spec.authors = ['Ben Zheng']
  spec.email = ['ben@ekohe.com']

  spec.summary = 'A flexible Ruby gem for orchestrating multiple LLM providers with unified interface'
  spec.description = 'LLM Conductor provides a clean, unified interface for working with multiple Language Model ' \
                     'providers including OpenAI GPT, OpenRouter, and Ollama. Features include prompt templating, ' \
                     'token counting, and extensible client architecture.'
  spec.homepage = 'https://github.com/ekohe/llm_conductor'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/ekohe/llm_conductor'
  spec.metadata['changelog_uri'] = 'https://github.com/ekohe/llm_conductor/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Core dependencies for LLM providers
  spec.add_dependency 'activesupport', '>= 6.0'
  spec.add_dependency 'anthropic', '~> 1.7'
  spec.add_dependency 'ollama-ai', '~> 1.3'
  spec.add_dependency 'ruby-openai', '~> 7.0'
  spec.add_dependency 'tiktoken_ruby', '~> 0.0.7'

  # Development dependencies
  spec.add_development_dependency 'rubocop-performance', '~> 1.19'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
