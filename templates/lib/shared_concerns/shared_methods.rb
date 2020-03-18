require "git-revision"

module Git
  class Revision
    class << self
      def dirty?
        !`git diff --numstat | wc -l`.strip.to_i.zero?
      end
    end
  end
end

module Concerns
  module SharedMethods
    extend ActiveSupport::Concern
    included do
      # Convert array
      def recipients_to_array(val)
        val.split(",").map do |email|
          {
            "Endpoint": email,
            "Protocol": "email-json"
          }
        end
      end

      # Returns 1 if enviroments[] match the environment, otherwise 0
      def get_resources_amount(environments = %w(production rspec))
        ((environments.include? ENV["ENVIRONMENT"]) && 1) || 0
      end

      def generate_stack_description(stack_name)
        "#{stack_name}-#{Git::Revision.commit}" \
        "#{Git::Revision.dirty? ? "-dirty" : ""}"
      end

      def generate_bootstrap_parameters
        warn "WARNING: .env.dependencies.#{ENV["ENVIRONMENT"]} does not exist. Run `rake dependencies` first!" unless File.file?(".env.dependencies.#{ENV["ENVIRONMENT"]}")
        filename = File.file?(".env.dependencies.#{ENV["ENVIRONMENT"]}") && ".env.dependencies#{environment == "rspec" && ".rspec" || ".#{ENV["ENVIRONMENT"]}"}" || ".env.dependencies.rspec"
        File.open(filename).read.each_line do |line|
          line.strip!
          param, _value = line.split("=")
          parameter param.to_sym,
                    description: param
        end
      end
    end
  end
end
