require "rubycfn"
require "dotenv"
require_relative "core/classes"

Dotenv.load(".env.private")
Dotenv.load(".env.dependencies.#{ENV["ENVIRONMENT"]}")
Dotenv.load(".env")
Dotenv.load(".env.#{ENV["ENVIRONMENT"]}")

# Include all group concerns
Dir[File.expand_path("../shared_concerns/", __FILE__) + "/**/*.rb"].sort.each do |file|
  require file
end

# SharedConcerns module is injected in each stack
module SharedConcerns
  extend ActiveSupport::Concern
  include Rubycfn

  included do
    include Concerns::GlobalVariables
  end
end

# Include all stack concerns
# Load module code first, and last include main.rb's.
2.times do |i|
  Dir[File.expand_path("../stacks/", __FILE__) + "/**/*.rb"].sort.each do |file|
    require file unless File.basename(file) == "main.rb" || i.positive?
    require file if File.basename(file) == "main.rb" && i.positive?
  end
end
