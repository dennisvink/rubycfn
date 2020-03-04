require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end

require "json"
require "launchy"
require "rspec"
require "rspec/its"
require "rspec/given"

ENV["ENVIRONMENT"] = "rspec"

RSpec.configure do |config|
  config.color = true
  config.formatter = "documentation"

  config.mock_with :rspec do |c|
    c.syntax = %i(should expect)
  end

  config.filter_run_excluding broken: true
  config.filter_run_excluding turn_off: true
  config.filter_run focus: true
  config.filter_run_excluding :slow unless ENV["SLOW_SPECS"]
  config.filter_run_excluding :debug unless ENV["DEBUG_SPECS"]
  config.run_all_when_everything_filtered = true
end
