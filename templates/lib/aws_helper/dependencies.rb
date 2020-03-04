def load_env_vars
  Dotenv.load(".env.private")
  Dotenv.load(".env.dependencies")
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
    stack_name: ENV["STACK_NAME"]
  }
end

def check_dependencies
  ENV["AWS_REGION"] ||= ENV["AWS_DEFAULT_REGION"]
  raise "AWS_REGION not set." unless ENV["AWS_REGION"]
  raise "CLOUDFORMATIONBUCKET not set. Run `rake init` and `rake update` first!" unless ENV["CLOUDFORMATIONBUCKET"]
  raise "ARTIFACTBUCKET not set. Run `rake init` and `rake update` first!" unless ENV["ARTIFACTBUCKET"]
  raise "ENVIRONMENT not set." unless ENV["ENVIRONMENT"]
  raise "STACK_NAME not set" unless ENV["STACK_NAME"]
  raise "AWS CREDENTIALS NOT SET" unless ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"]
end
