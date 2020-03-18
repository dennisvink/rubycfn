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
    stack_name: "<%= project_name %>DependencyStack"
  )
rescue Aws::CloudFormation::Errors::InvalidClientTokenId, Aws::CloudFormation::Errors::ValidationError => e
  puts "E: #{e.class}"
  raise "ERROR: Your AWS credentials are not set or invalid." if e.class == Aws::CloudFormation::Errors::InvalidClientTokenId
  raise "ERROR: <%= project_name %>DependencyStack does not exist. Run `rake init` first!" if e.class == Aws::CloudFormation::Errors::ValidationError
end

dep_file = File.open(".env.dependencies.#{ENV["ENVIRONMENT"]}", "w")
res[:stacks].each do |stack|
  stack[:outputs].each do |output|
    dep_file.puts "#{output[:output_key].upcase}=#{output[:output_value]}"
  end
end
