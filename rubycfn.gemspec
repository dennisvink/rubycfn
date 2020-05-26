# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rubycfn/version"

Gem::Specification.new do |spec|
  spec.name          = "rubycfn"
  spec.version       = Rubycfn::VERSION
  spec.authors       = ["Dennis Vink"]
  spec.email         = ["dennis@drvink.com"]
  spec.summary       = "Rubycfn"
  spec.description   = "RubyCFN is a light-weight CloudFormation DSL"
  spec.homepage      = "https://github.com/dennisvink/rubycfn"
  spec.required_ruby_version = ">= 2.2.0"
  spec.license       = "MIT"
  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/(?:test|spec|features)/)
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "neatjson", "~> 0.8.4"
  spec.add_runtime_dependency "json", "~> 2.1.0"
  spec.add_runtime_dependency "activesupport", ">= 5.1.5", "< 6.1.0"
  spec.add_runtime_dependency "tty-prompt", "~> 0.16.0"
  spec.add_runtime_dependency "dotenv", "~> 2.4.0"

  spec.add_development_dependency "awesome_print", "~> 1.2"
  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "guard-rspec", "~> 4.3"
  spec.add_development_dependency "guard", "~> 2.6"
  spec.add_development_dependency "launchy", "~> 2.4"
  spec.add_development_dependency "pry", "~> 0.10"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.2"
  spec.add_development_dependency "rspec-given", "~> 3.7"
  spec.add_development_dependency "rspec-its", "~> 1.2"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.2"
  spec.add_development_dependency "simplecov", "~> 0.9"
end
