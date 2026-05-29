# frozen_string_literal: true

require_relative "lib/console_historian/version"

Gem::Specification.new do |spec|
  spec.name = "console_historian"
  spec.version = ConsoleHistorian::VERSION
  spec.authors = ["Kellen Baker"]
  spec.email = ["mkellenbaker@gmail.com"]

  spec.summary = "Records Rails console sessions and generates LLM-powered runbooks"
  spec.description = "Transparently wraps Rails console sessions, captures commands and outputs, " \
                     "redacts sensitive values, and uses an LLM to produce a reusable Markdown runbook on exit."
  spec.homepage = "https://github.com/mkellenbaker/console_historian"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*", "*.md", "*.gemspec", "Gemfile", "Rakefile"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rails", ">= 7.0"
  spec.add_development_dependency "rubocop", "~> 1.60"
end
