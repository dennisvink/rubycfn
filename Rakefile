require "bundler/gem_tasks"
Bundler::GemHelper.install_tasks

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = \
    " --format RspecJunitFormatter" \
    " --out test-reports/rspec.xml"
end

task default: %i(spec)
