# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "dev_experience"
  spec.version = "0.1.0"
  spec.authors = ["Eric Laquer"]
  spec.summary = "Rails engine for UML analysis with Hindsight memory integration"
  spec.description = "Provides Template/App UML browsing (Actors, Use Cases, Sequences) " \
                     "and syncs specs to Hindsight memory banks"
  spec.homepage = "https://github.com/laquereric/dev-experience-coc-2026-q2"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "db/**/*", "VERSION"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 8.1"
  spec.add_dependency "hindsight"
  spec.add_dependency "view_component"
  spec.add_dependency "view_component-contrib"
  spec.add_dependency "dry-initializer"
  spec.add_dependency "ruby_llm"
  spec.add_dependency "context-record"
end
