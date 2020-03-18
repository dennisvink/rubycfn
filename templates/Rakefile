require "rubygems"
require "bundler"
require "rspec/core/rake_task"
require "rubocop/rake_task"

Bundler.setup

RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = \
    " --format RspecJunitFormatter" \
    " --out test-reports/rspec.xml"
end

desc "Apply CloudFormation template"
task :apply_stack do
  require_relative "lib/main"
  require_relative "lib/core/deploy"
end

desc "Upload stacks to s3"
task :upload_stack do
  require_relative "lib/main"
  require_relative "lib/core/upload"
end

desc "Initialize AWS Account"
task :init do
  require_relative "lib/core/init"
end

desc "Clean build directory"
task :clean do
  Dir.foreach("build/") do |f|
    fn = File.join("build/", f)
    File.delete(fn) if f != "." && f != ".."
  end
end

desc "Store dependencies of DependencyStack in .env.dependencies.<ENVIRONMENT>"
task :dependencies do
  require_relative "lib/core/dependencies.rb"
end

desc "Compile CloudFormation"
task :compile_stack do
  require_relative "lib/main"
  require_relative "lib/core/compile"
end

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ["--display-cop-names"]
end

task default: %i(dependencies compile_stack spec)
task compile: %i(dependencies compile_stack)
task upload: %i(dependencies upload_stack)
task apply: %i(dependencies apply_stack)
