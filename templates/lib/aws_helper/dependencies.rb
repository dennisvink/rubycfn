def infra_config
  config = YAML.safe_load(File.read("config.yaml"), [Symbol])
  config["applications"] ||= {}
  config["environments"] ||= {}
  config["subnets"] ||= {}
  config
end

def load_env_vars
  Dotenv.load(".env.private")
  Dotenv.load(".env.dependencies.#{ENV["ENVIRONMENT"]}")
  Dotenv.load(".env")
  Dotenv.load(".env.#{ENV["ENVIRONMENT"]}")

  check_dependencies
  {
    artifact_bucket: ENV["ARTIFACTBUCKET"],
    aws_region: ENV["AWS_REGION"],
    aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
    aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
    cloudformation_bucket: ENV["CLOUDFORMATIONBUCKET"],
    environment: ENV["ENVIRONMENT"],
    stack_name: infra_config["environments"][ENV["ENVIRONMENT"]]["stack_name"]
  }
end

def check_dependencies
  ENV["AWS_REGION"] ||= ENV["AWS_DEFAULT_REGION"]
  raise "AWS_REGION not set." unless ENV["AWS_REGION"]
  raise "CLOUDFORMATIONBUCKET not set. Run `rake init` and `rake update` first!" unless ENV["CLOUDFORMATIONBUCKET"]
  raise "ARTIFACTBUCKET not set. Run `rake init` and `rake update` first!" unless ENV["ARTIFACTBUCKET"]
  raise "ENVIRONMENT not set." unless ENV["ENVIRONMENT"]
  raise "`stack_name` not configured in config.yaml" unless infra_config["environments"][ENV["ENVIRONMENT"]]["stack_name"]
  raise "AWS CREDENTIALS NOT SET" unless ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"]
end
