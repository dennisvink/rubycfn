require "aws-sdk"
require "dotenv"
require "git-revision"
require "rubycfn"
require "yaml"

require_relative "../aws_helper/main"

Dotenv.load(".env.private")
Dotenv.load(".env")
Dotenv.load(".env.#{ENV["ENVIRONMENT"]}")

set_aws_credentials(
  ENV["AWS_REGION"],
  ENV["AWS_ACCESS_KEY_ID"],
  ENV["AWS_SECRET_ACCESS_KEY"]
)

def inject_dummy_resource(stack)
  hack_stack = JSON.parse(stack)
  hack_stack["Resources"] = {} if hack_stack["Resources"].nil?
  hack_stack["Resources"]["CloudFormationDummyResource"] = {
    "Type": "AWS::CloudFormation::WaitConditionHandle",
    "Metadata": {
      "Comment": "Resource to update stack even if there are no changes",
      "GitCommitHash": Git::Revision.commit
    }
  }
  hack_stack.to_json
end

def read_domain_name
  config = YAML.safe_load(File.read("config.yaml"), [Symbol])
  config["applications"] ||= {}
  config["environments"] ||= {}
  config["subnets"] ||= {}

  # Allow override by setting ENV var
  domain_name = ENV["DOMAIN_NAME"]
  subdomain = ENV["SUBDOMAIN"] # rubocop:disable Lint/UselessAssignment

  # First, look at environment specific domain name configuration
  domain_name ||= config["environments"][ENV["ENVIRONMENT"]]["domain_name"].nil? && nil || config["environments"][ENV["ENVIRONMENT"]]["domain_name"]

  # Assign the global domain name configuration unless domain_name was set to false in environment config.yaml
  domain_name ||= config["domain_name"] unless domain_name.class == FalseClass

  # Set domain name to an empty string if domain_name was set to false
  domain_name = "" if domain_name.class == FalseClass

  # If the no_subdomain setting for environments in config.yaml is omitted or set to false, set subdomain to environment, else assign empty string
  subdomain = (config["environments"][ENV["ENVIRONMENT"]]["no_subdomain"].nil? || config["environments"][ENV["ENVIRONMENT"]]["no_subdomain"] == false) && ENV["ENVIRONMENT"] || ""

  # Return an array with t he subdomain and domain_name
  [subdomain, domain_name]
end

subdomain, domain_name = read_domain_name

raise "ENVIRONMENT not set" unless ENV["ENVIRONMENT"]
warn "WARNING: domain_name not set in config.yaml... Route53 Hosted Zone will not be created" if domain_name.empty?

module <%= project_name %>DependencyStack
  extend ActiveSupport::Concern
  include Rubycfn

  included do
    description "<%= project_name %>Dependency Stack"

    parameter :environment,
              description: "Environment name",
              type: "String"

    parameter :domain_name,
              description: "Domain name",
              type: "String"

    condition :has_environment,
              [["", :environment.ref].fnequals].fnnot

    condition :has_domain_name,
              [["", :domain_name.ref].fnequals].fnnot

    %i(
      artifact_bucket
      cloudformation_bucket
      lambda_bucket
      logging_bucket
    ).each do |bucket|
      resource bucket,
               deletion_policy: "Retain",
               update_replace_policy: "Retain",
               type: "AWS::S3::Bucket"

      output bucket,
             value: bucket.ref
    end

    resource :hosted_zone,
             condition: "HasDomainName",
             type: "AWS::Route53::HostedZone" do |r|
      r.property(:hosted_zone_config) do
        {
          "Comment": ["Hosted zone for ", ["HasEnvironment", [:environment.ref, "."].fnjoin, ""].fnif, :domain_name.ref].fnjoin
        }
      end
      r.property(:name) { [["HasEnvironment", [:environment.ref, "."].fnjoin, ""].fnif, :domain_name.ref].fnjoin }
    end

    output :hosted_zone_id,
           condition: "HasDomainName",
           value: :hosted_zone.ref

    output :hosted_zone_name,
           condition: "HasDomainName",
           value: [["HasEnvironment", [:environment.ref, "."].fnjoin, ""].fnif, :domain_name.ref].fnjoin
  end
end

stack = include <%= project_name %>DependencyStack # rubocop:disable Style/MixinUsage
template = stack.render_template

client = Aws::CloudFormation::Client.new

stack_exists = false
previous_statuses = []
80.times do
  previous_events = get_prior_events(client, "<%= project_name %>DependencyStack")
  previous_statuses = previous_events.map(&:event_id)
  stack_exists = previous_events.size.to_i.positive? ? true : false
  break unless stack_exists

  events_last_deploy = get_events_last_deploy(previous_events)
  last_event = events_last_deploy.shift
  break if last_event \
    && (last_event.logical_resource_id == "<%= project_name %>DependencyStack") \
    && (last_event.stack_name == "<%= project_name %>DependencyStack") \
    && (DEPLOYABLE_STATES.include? last_event.resource_status)
  puts "Stack is currently in #{last_event.resource_status} mode. Waiting for it to finish..." if last_event
  sleep 15
end

template = inject_dummy_resource(template)

parameters = [
  {
    parameter_key: "Environment",
    parameter_value: subdomain
  },
  {
    parameter_key: "DomainName",
    parameter_value: domain_name
  }
]

if stack_exists
  client.update_stack(
    stack_name: "<%= project_name %>DependencyStack",
    template_body: template,
    capabilities: %w(CAPABILITY_IAM CAPABILITY_NAMED_IAM),
    parameters: parameters,
    tags: [
      {
        key: "team",
        value: "infra"
      }
    ]
  )
else
  client.create_stack(
    stack_name: "<%= project_name %>DependencyStack",
    template_body: template,
    timeout_in_minutes: 60,
    capabilities: %w(CAPABILITY_IAM CAPABILITY_NAMED_IAM),
    on_failure: "ROLLBACK",
    parameters: parameters,
    tags: [
      {
        key: "team",
        value: "infra"
      }
    ],
    enable_termination_protection: false
  )
end

shown_log_lines = {}

360.times do
  resp = client.describe_stack_events(
    stack_name: "<%= project_name %>DependencyStack"
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
    if (@stack_name == "<%= project_name %>DependencyStack") \
      && (@logical_resource_id == "<%= project_name %>DependencyStack") \
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
