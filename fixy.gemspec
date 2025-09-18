lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "fixy/version"

Gem::Specification.new do |spec|
  spec.name = "fixy"
  spec.version = Fixy::VERSION
  spec.authors = ["Omar Skalli", "Daniel Rench"]
  spec.email = ["omar@zenpayroll.com"]
  spec.description = "Library for generating fixed width flat files."
  spec.summary = "Provides a DSL for defining, generating, and debugging fixed width documents."
  spec.homepage = "https://github.com/chetane/fixy"
  spec.license = "MIT"

  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.3.0"

  spec.add_development_dependency "guard-rspec", "~> 4"
  spec.add_development_dependency "rspec", "~> 3"
  spec.add_development_dependency "simplecov", "~> 0"
  spec.add_development_dependency "standard", "~> 1"
end
