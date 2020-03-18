require "colorize"
require "digest/md5"
require "dotenv"
require "aws-sdk-s3"
require "aws-sdk"

require_relative "../aws_helper/main"

Dotenv.load(".env.private")
Dotenv.load(".env.dependencies.#{ENV["ENVIRONMENT"]}")
raise "CLOUDFORMATIONBUCKET not set. Run `rake init` and `rake update` first!" unless ENV["CLOUDFORMATIONBUCKET"]

env_vars = load_env_vars

set_aws_credentials(
  env_vars[:aws_region],
  env_vars[:aws_access_key_id],
  env_vars[:aws_secret_access_key]
)

s3_filename = get_parent_stack_s3_location(
  ENV["CLOUDFORMATIONBUCKET"],
  env_vars[:environment]
)

client = Aws::CloudFormation::Client.new

parent_parameters = []
File.open(".env.dependencies.#{ENV["ENVIRONMENT"]}").read.each_line do |line|
  line.strip!
  param, value = line.split("=")
  parent_parameters.push(
    parameter_key: param,
    parameter_value: value
  )
end

# Store previous CloudFormation events in an array, so that we don't output
# events from previous deploys.

stack_exists = false
previous_statuses = []
80.times do
  previous_events = get_prior_events(client, env_vars[:stack_name])
  previous_statuses = previous_events.map(&:event_id)
  stack_exists = previous_events.size.to_i.positive? ? true : false
  break unless stack_exists

  events_last_deploy = get_events_last_deploy(previous_events)
  last_event = events_last_deploy.shift
  break if last_event \
    && (last_event.logical_resource_id == env_vars[:stack_name]) \
    && (last_event.stack_name == env_vars[:stack_name]) \
    && (DEPLOYABLE_STATES.include? last_event.resource_status)
  puts "Stack is currently in #{last_event.resource_status} mode. Waiting for it to finish..." if last_event
  sleep 15
end

if stack_exists
  client.update_stack(
    stack_name: env_vars[:stack_name],
    template_url: s3_filename,
    capabilities: %w(CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND),
    parameters: parent_parameters,
    tags: [
      {
        key: "team",
        value: "infra"
      }
    ]
  )
else
  client.create_stack(
    stack_name: env_vars[:stack_name],
    template_url: s3_filename,
    timeout_in_minutes: 60,
    capabilities: %w(CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND),
    on_failure: "ROLLBACK",
    parameters: parent_parameters,
    tags: [
      {
        key: "team",
        value: "infra"
      }
    ],
    enable_termination_protection: false
  )
end

## Rudimentary feedback for CI/CD
shown_log_lines = {}

360.times do
  resp = client.describe_stack_events(
    stack_name: env_vars[:stack_name]
  )
  resp.stack_events.to_a.reverse.each_with_index do |event, index|
    next if previous_statuses.include? event.event_id
    @completed = false
    @stack_name = event.stack_name
    @logical_resource_id = event.logical_resource_id
    @resource_type = event.resource_type
    @timestamp = event.timestamp
    @resource_status = event.resource_status
    @resource_status_reason = event.resource_status_reason
    log_line = "[#{@logical_resource_id.green}] #{@timestamp.to_s.blue}: " \
               "#{@resource_status.white} #{@resource_status_reason.to_s.red}"
    puts log_line unless shown_log_lines[log_line]
    shown_log_lines[log_line] = true
    if (@stack_name == env_vars[:stack_name]) \
      && (@logical_resource_id == env_vars[:stack_name]) \
      && (END_STATES.include? @resource_status) \
      && (index + 1 == resp.stack_events.to_a.size)
      @completed = true
    end
  end
  if @completed
    puts "==================================="
    puts " STATUS: #{@resource_status} #{@resource_status_reason}"
    puts "==================================="
    raise "#{@resource_status} #{@resource_status_reason}" if FAILURE_STATES.include? @resource_status
    break
  end
  sleep(10)
end
