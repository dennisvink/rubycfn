require "aws-sdk-core"
require "aws-sdk-cloudformation"
require "dotenv"

Dotenv.load(".env.private")
Dotenv.load(".env")
Dotenv.load(".env.#{ENV["ENVIRONMENT"]}")

ENV["AWS_DEFAULT_REGION"] ||= "eu-west-1"
ENV["AWS_REGION"] ||= ENV["AWS_DEFAULT_REGION"]

client = Aws::CloudFormation::Client.new(region: ENV["AWS_REGION"])

begin
  res = client.describe_stacks(
    stack_name: "DependencyStack"
  )
rescue Aws::CloudFormation::Errors::InvalidClientTokenId
  raise "ERROR: Your AWS credentials are not set or invalid."
end

raise "ERROR: .env.dependencies does not exist. Run `rake init` and `rake dependencies` first!" unless File.file?(".env.dependencies")
dep_file = File.open(".env.dependencies", "w")
res[:stacks].each do |stack|
  stack[:outputs].each do |output|
    dep_file.puts "#{output[:output_key].upcase}=#{output[:output_value]}"
  end
end
