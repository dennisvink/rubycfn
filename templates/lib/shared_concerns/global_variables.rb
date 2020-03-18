require "yaml"

module Concerns
  module GlobalVariables
    extend ActiveSupport::Concern

    included do
      def load_config(_val)
        config = YAML.safe_load(File.read("config.yaml"), [Symbol])
        config["applications"] ||= {}
        config["environments"] ||= {}
        config["subnets"] ||= {}
        config
      end

      def global_tags(_val)
        [
          {
            "Key": "Team",
            "Value": "infra"
          },
          {
            "Key": "Environment",
            "Value": environment.to_s
          },
          {
            "Key": "StackName",
            "Value": stack_name.to_s
          }
        ]
      end

      variable :environment,
               default: "development",
               global: true,
               value: ENV["ENVIRONMENT"]

      variable :region,
               global: true,
               default: ENV["DEFAULT_AWS_REGION"],
               value: ENV["AWS_REGION"]

      variable :infra_config,
               global: true,
               filter: :load_config

      variable :stack_name,
               global: true,
               default: infra_config["environments"][environment]["stack_name"]

      variable :default_tags,
               global: true,
               filter: :global_tags
    end
  end
end
