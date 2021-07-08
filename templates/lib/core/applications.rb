def to_bool(val)
  return false unless val.nil? || val.empty?
  return false unless val != "true"
  true
end

def env_vars_to_array(val)
  if val.nil? || val.empty?
    return [
      {
        Name: "WITHOUT_ENV",
        Value: "true"
      }
    ]
  end
  vars = []

  # Create an array of variables to pass to this application.
  # Resolve any references to its intrinsic function.
  val.keys.each_with_index do |object, index|
    value = val.values[index].class == Symbol && Kernel.class_eval(":#{val.values[index]}") || val.values[index]

    # Support ${ENV_VAR} in config_yaml
    if value =~ /\$\{([^\}]*)\}/
      capture = $1
      value = ENV[capture]
    end

    vars.push(
      Name: object,
      Value: value
    )
  end
  vars
end

@ignore_params = {}

# Return the mandatory Stack parameters and add all defined ENV vars from config.yaml
def parent_parameters(env_vars, simple_name)
  params = {
    "Vpc": :vpc_stack.ref("Outputs.Vpc"),
    "Cluster": :ecs_stack.ref("Outputs.EcsCluster"),
    "Listener": :ecs_stack.ref("Outputs.EcsLoadBalancerListener"),
    "EcsServiceAutoScalingRoleArn": :ecs_stack.ref("Outputs.EcsAutoScalingRoleArn"),
    "HostedZoneId": "HOSTEDZONEID".ref,
    "HostedZoneName": "HOSTEDZONENAME".ref,
    "LoadBalancerDnsName": :ecs_stack.ref("Outputs.EcsLoadBalancerUrl"),
    "CanonicalHostedZoneId": :ecs_stack.ref("Outputs.EcsLoadBalancerHostedZoneId"),
    "CertificateProviderFunctionArn": :acm_stack.ref("Outputs.CertificateProviderFunctionArn"),
    "ApplicationDeploymentFailureRollbackFunctionArn": :ecs_stack.ref("Outputs.ApplicationDeploymentFailureRollbackFunctionArn")
  }

  env_vars.each do |var|
    TOPLEVEL_BINDING.eval("@ignore_params[:#{simple_name}] ||= []")
    if var[:Value].class == Hash && var[:Value].keys[0] == :Ref
      TOPLEVEL_BINDING.eval("@ignore_params[:#{simple_name}].push(\"#{var[:Name]}\")")
      next
    end
    params[var[:Name].cfnize] = var[:Value]
  end
  params
end

def application_parameters(env_vars)
  vars = []

  env_vars.each do |var|
    if var[:Value].class == Hash && var[:Value].keys[0] == :Ref
      vars.push(
        Name: var[:Name],
        Value: var[:Value]
      )
    else
      vars.push(
        Name: var[:Name],
        Value: var[:Name].cfnize.ref
      )
    end
  end
  vars
end

# Generate nested stacks for each defined application, and create module dynamically.
def create_applications
  return if infra_config["environments"][environment]["cluster_size"].nil? || infra_config["environments"][environment]["cluster_size"].to_i.zero?
  resource :applications_stack,
           amount: infra_config["applications"].count,
           type: "AWS::CloudFormation::Stack" do |r, index|
    env_vars = env_vars_to_array(infra_config["applications"].values[index]["env"])
    application_vars = application_parameters(env_vars) # rubocop:disable Lint/UselessAssignment
    name = infra_config["applications"].keys[index]
    resource_name = name.tr("-", "_").cfnize
    simple_name = resource_name.downcase
    app_config = infra_config["applications"].values[index]
    is_essential = to_bool(app_config["essential"].to_s)

    r._id("#{resource_name}Stack")
    r.property(:template_url) { "#{simple_name}stack" }
    r.property(:parameters) { parent_parameters(env_vars, simple_name) }
    Object.const_set("#{resource_name}Stack", Module.new).class_eval <<-RUBY
      extend ActiveSupport::Concern
      include Rubycfn

      included do

        def get_aliases(val)
          aliases = []
          return aliases if val["aliases"].nil?
          return aliases if val["aliases"][environment].nil?
          val["aliases"][environment]
        end

        ignore_params = TOPLEVEL_BINDING.eval("@ignore_params[:#{simple_name}]")
        application_vars.each do |var|
          next if ignore_params.include? var[:Name]
          Object.class_eval("parameter var[:Name].to_sym, description: 'Value for ENV var \#{var[:Name]}'")
        end

        parameter :vpc,
                  description: "The VPC that the ECS cluster is deployed to",
                  type: "AWS::EC2::VPC::Id"

        parameter :cluster,
                  description: "ECS Cluster ID",
                  type: "String"

        parameter :listener,
                  description: "The Application Load Balancer listener to register with",
                  type: "String"

        parameter :ecs_service_auto_scaling_role_arn,
                  description: "The ECS service auto scaling role ARN",
                  type: "String"

        parameter :hosted_zone_id,
                  description: "Hosted Zone ID",
                  type: "String"

        parameter :hosted_zone_name,
                  description: "Hosted Zone Name",
                  type: "String"

        parameter :load_balancer_dns_name,
                  description: "URL of the ECS ALB",
                  type: "String"

        parameter :canonical_hosted_zone_id,
                  description: "Canonical Hosted Zone Id of ALB",
                  type: "String"

        parameter :certificate_provider_function_arn,
                  description: "ARN of certificate provider",
                  type: "String"

        parameter :application_deployment_failure_rollback_function_arn,
                  description: "ARN of ECS deployment failure Lambda",
                  type: "String"

        variable :aliases,
                 value: app_config,
                 filter: :get_aliases

        variable :min_override,
                 value: app_config[environment].nil? ? "" : app_config[environment]["min"].to_s

        variable :min,
                 value: min_override.empty? ? app_config["min"].to_s : min_override

        variable :max_override,
                 value: app_config[environment].nil? ? "" : app_config[environment]["max"].to_s

        variable :max,
                 value: max_override.empty? ? app_config["max"].to_s : max_override

        variable :container_port,
                 value: app_config["container_port"].to_s

        variable :memory_override,
                 value: app_config[environment].nil? ? "" : app_config[environment]["mem"].to_s

        variable :memory,
                 value: memory_override.empty? ? app_config["mem"].to_s : memory_override

        variable :image,
                 value: app_config["image"]

        variable :env_vars,
                 value: app_config["env"],
                 filter: :env_vars_to_array

        variable :priority,
                 value: app_config["priority"].to_s


        description generate_stack_description("#{resource_name}Stack")

        resource :service,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::ECS::Service" do |r|
          r.property(:service_name) { "#{environment}-<%= project_name %>-#{simple_name}" }
          r.property(:cluster) { :cluster.ref }
          r.property(:role) { :service_role.ref }
          r.property(:health_check_grace_period_seconds) { 120 }
          r.property(:desired_count) { min.to_i }
          r.property(:task_definition) { :task_definition.ref }
          r.property(:load_balancers) do
            [
              "ContainerName": "#{simple_name}-service",
              "ContainerPort": container_port.to_i,
              "TargetGroupArn": :target_group.ref
            ]
          end
        end

        resource :application_deployment_health,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "Custom::EcsDeploymentCheck" do |r|
          r.property(:service_token) { :application_deployment_failure_rollback_function_arn.ref }
          r.property("AWSRegion") { "${AWS::Region}".fnsub }
          r.property(:service) { "#{environment}-<%= project_name %>-#{simple_name}" }
          r.property(:cluster) { :cluster.ref }
        end

        resource :task_definition,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::ECS::TaskDefinition" do |r|
          r.property(:family) { "#{simple_name}-service" }
          r.property(:container_definitions) do
            [
              {
                "Name": "#{simple_name}-service",
                "Essential": #{is_essential},
                "Image": image,
                "Memory": memory.to_i,
                "Environment": application_vars,
                "PortMappings": [
                  {
                    "ContainerPort": container_port.to_i
                  }
                ],
                "LogConfiguration": {
                  "LogDriver": "awslogs",
                  "Options": {
                    "awslogs-group": :cloud_watch_logs_group.ref,
                    "awslogs-region": "AWS::Region".ref
                  }
                }
              }
            ]
          end
        end

        resource :cloud_watch_logs_group,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::Logs::LogGroup" do |r|
          r.property(:log_group_name) { ["AWS::StackName".ref, "-#{simple_name}"].fnjoin }
          r.property(:retention_in_days) { 30 }
        end

        resource :target_group,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::ElasticLoadBalancingV2::TargetGroup" do |r|
          r.property(:vpc_id) { :vpc.ref }
          r.property(:port) { container_port.to_i }
          r.property(:protocol) { "HTTP" }
          r.property(:matcher) do
            {
              "HttpCode": "200-299"
            }
          end
          r.property(:health_check_interval_seconds) { 10 }
          r.property(:health_check_path) { "/" }
          r.property(:health_check_protocol) { "HTTP" }
          r.property(:health_check_timeout_seconds) { 5 }
          r.property(:healthy_threshold_count) { 2 }
        end

        resource :listener_rule,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::ElasticLoadBalancingV2::ListenerRule" do |r|
          r.property(:listener_arn) { :listener.ref }
          r.property(:priority) { priority.to_i }
          r.property(:conditions) do
            [
              {
                "Field": "host-header",
                "Values": [
                  ["origin", name.tr("_", "-"), :hosted_zone_name.ref].fnjoin("."),
                  [name.tr("_", "-"), :hosted_zone_name.ref].fnjoin(".")
                ] + aliases
              }
            ]
          end
          r.property(:actions) do
            [
              {
                "TargetGroupArn": :target_group.ref,
                "Type": "forward"
              }
            ]
          end
        end

        assume_role_policy_document = {
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "Service": [
                  "ecs.amazonaws.com"
                ]
              },
              "Action": [
                "sts:AssumeRole"
              ]
            }
          ]
        }

        resource :service_role,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::IAM::Role" do |r|
          r.property(:role_name) { "ecs-service-${AWS::StackName}".fnsub }
          r.property(:path) { "/" }
          r.property(:assume_role_policy_document) { JSON.pretty_generate(assume_role_policy_document) }
          r.property(:policies) do
            [
              {
                "PolicyName": "ecs-service-${AWS::StackName}".fnsub,
                "PolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Action": [
                        "ec2:AuthorizeSecurityGroupIngress",
                        "ec2:Describe*",
                        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                        "elasticloadbalancing:Describe*",
                        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                        "elasticloadbalancing:DeregisterTargets",
                        "elasticloadbalancing:DescribeTargetGroups",
                        "elasticloadbalancing:DescribeTargetHealth",
                        "elasticloadbalancing:RegisterTargets"
                      ],
                      "Resource": "*"
                    },
                    {
                      "Effect": "Allow",
                      "Action": [
                        "ec2:DescribeTags",
                        "ecs:CreateCluster",
                        "ecs:DeregisterContainerInstance",
                        "ecs:DiscoverPollEndpoint",
                        "ecs:Poll",
                        "ecs:RegisterContainerInstance",
                        "ecs:StartTelemetrySession",
                        "ecs:UpdateContainerInstancesState",
                        "ecs:Submit*",
                        "ecr:GetAuthorizationToken",
                        "ecr:BatchCheckLayerAvailability",
                        "ecr:GetDownloadUrlForLayer",
                        "ecr:BatchGetImage",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents"
                      ],
                      "Resource": "*"
                    }
                  ]
                }
              }
            ]
          end
        end

        resource :application_load_balancer_record,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::Route53::RecordSet" do |r|
          r.property(:type) { "A" }
          r.property(:name) { ["origin", name.tr("_", "-"), :hosted_zone_name.ref].fnjoin(".") }
          r.property(:hosted_zone_id) { :hosted_zone_id.ref }
          r.property(:alias_target) do
            {
              "DNSName": :load_balancer_dns_name.ref,
              "EvaluateTargetHealth": true,
              "HostedZoneId": :canonical_hosted_zone_id.ref
            }
          end
        end

        resource :service_scalable_target,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::ApplicationAutoScaling::ScalableTarget" do |r|
          r.property(:max_capacity) { max.to_i }
          r.property(:min_capacity) { min.to_i }
          r.property(:resource_id) { ["service", :cluster.ref, :service.ref(:name)].fnjoin("/") }
          r.property(:role_arn) { :ecs_service_auto_scaling_role_arn.ref }
          r.property(:scalable_dimension) { "ecs:service:DesiredCount" }
          r.property(:service_namespace) { "ecs" }
        end

        resource :service_scale_out_policy,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::ApplicationAutoScaling::ScalingPolicy" do |r|
          r.property(:policy_name) { "ServiceScaleOutPolicy" }
          r.property(:policy_type) { "StepScaling" }
          r.property(:scaling_target_id) { :service_scalable_target.ref }
          r.property(:step_scaling_policy_configuration) do
            {
              "AdjustmentType": "ChangeInCapacity",
              "Cooldown": 300,
              "MetricAggregationType": "Average",
              "StepAdjustments": [
                {
                  "MetricIntervalLowerBound": 0,
                  "ScalingAdjustment": 1
                }
              ]
            }
          end
        end

        resource :service_scale_in_policy,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::ApplicationAutoScaling::ScalingPolicy" do |r|
          r.property(:policy_name) { "ServiceScaleInPolicy" }
          r.property(:policy_type) { "StepScaling" }
          r.property(:scaling_target_id) { :service_scalable_target.ref }
          r.property(:step_scaling_policy_configuration) do
            {
              "AdjustmentType": "ChangeInCapacity",
              "Cooldown": 600,
              "MetricAggregationType": "Average",
              "StepAdjustments": [
                {
                  "MetricIntervalUpperBound": 0,
                  "ScalingAdjustment": -1
                }
              ]
            }
          end
        end

        resource :cpu_scale_out_alarm,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::CloudWatch::Alarm" do |r|
          r.property(:alarm_name) { "CPU utilization greater than 90% on #{simple_name}-#{environment}" }
          r.property(:alarm_description) { "Alarm if cpu utilization greater than 90% of reserved cpu" }
          r.property(:namespace) { "AWS/ECS" }
          r.property(:metric_name) { "CPUUtilization" }
          r.property(:dimensions) do
            [
              {
                "Name": "ClusterName",
                "Value": :cluster.ref
              },
              {
                "Name": "ServiceName",
                "Value": :service.ref(:name)
              }
            ]
          end
          r.property(:statistic) { "Maximum" }
          r.property(:period) { "60" }
          r.property(:evaluation_periods) { "3" }
          r.property(:threshold) { "90" }
          r.property(:comparison_operator) { "GreaterThanThreshold" }
          r.property(:alarm_actions) { [:service_scale_out_policy.ref] }
        end

        resource :cpu_scale_in_alarm,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::CloudWatch::Alarm" do |r|
          r.property(:alarm_name) { "CPU utilization less than 70% on #{simple_name}-#{environment}" }
          r.property(:alarm_description) { "Alarm if cpu utilization greater than 70% of reserved cpu" }
          r.property(:namespace) { "AWS/ECS" }
          r.property(:metric_name) { "CPUUtilization" }
          r.property(:dimensions) do
            [
              {
                "Name": "ClusterName",
                "Value": :cluster.ref
              },
              {
                "Name": "ServiceName",
                "Value": :service.ref(:name)
              }
            ]
          end
          r.property(:statistic) { "Maximum" }
          r.property(:period) { "60" }
          r.property(:evaluation_periods) { "10" }
          r.property(:threshold) { "70" }
          r.property(:comparison_operator) { "LessThanThreshold" }
          r.property(:alarm_actions) { [:service_scale_in_policy.ref] }
        end

        resource :ecs_application_certificate,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "Custom::Certificate" do |r|
          r.property(:service_token) { :certificate_provider_function_arn.ref }
          r.property(:region) { "us-east-1" }
          r.property(:domain_name) { [name.tr("_", "-"), :hosted_zone_name.ref].fnjoin(".") }
          r.property(:validation_method) { "DNS" }
        end

        resource :ecs_application_issued_certificate,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "Custom::IssuedCertificate" do |r|
          r.property(:service_token) { :certificate_provider_function_arn.ref }
          r.property(:region) { "us-east-1" }
          r.property(:certificate_arn) { :ecs_application_certificate.ref }
        end

        resource :ecs_application_dns_record,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "Custom::CertificateDNSRecord" do |r|
          r.property(:service_token) { :certificate_provider_function_arn.ref }
          r.property(:region) { "us-east-1" }
          r.property(:domain_name) { [name.tr("_", "-"), :hosted_zone_name.ref].fnjoin(".") }
          r.property(:certificate_arn) { :ecs_application_certificate.ref }
        end

        resource :ecs_application_validation_record,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::Route53::RecordSetGroup" do |r|
          r.property(:hosted_zone_id) { :hosted_zone_id.ref }
          r.property(:record_sets) do
            [
              {
                "Name": :ecs_application_dns_record.ref(:name),
                "Type": :ecs_application_dns_record.ref(:type),
                "TTL": 60,
                "Weight": 1,
                "SetIdentifier": :ecs_application_certificate.ref,
                "ResourceRecords": [
                  :ecs_application_dns_record.ref(:value)
                ]
              }
            ]
          end
        end

        resource :cloudfront_distribution,
                 depends_on: [
                   :ecs_application_issued_certificate,
                   :application_deployment_health
                 ],
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::CloudFront::Distribution" do |r|
          r.property(:distribution_config) do
            {
              "Comment": ["Distribution config for", [name.tr("_", "-"), :hosted_zone_name.ref].fnjoin(".")].fnjoin(" "),
              "Aliases": [
                [name.tr("_", "-"), :hosted_zone_name.ref].fnjoin(".")
              ],
              "DefaultCacheBehavior": {
                "AllowedMethods": %w(GET HEAD OPTIONS PUT PATCH POST DELETE),
                "DefaultTTL": 0,
                "TargetOriginId": "EcsApplication",
                "ForwardedValues": {
                  "QueryString": true,
                  "Cookies": {
                    "Forward": "all"
                  },
                  "Headers": ["*"]
                },
                "MaxTTL": 0,
                "MinTTL": 0,
                "ViewerProtocolPolicy": "redirect-to-https"
              },
              "Enabled": true,
              "HttpVersion": "http2",
              "IPV6Enabled": false,
              "Origins": [
                {
                  "DomainName": ["origin", name.tr("_", "-"), :hosted_zone_name.ref].fnjoin("."),
                  "Id": "EcsApplication",
                  "CustomOriginConfig": {
                    "OriginProtocolPolicy": "http-only",
                    "HTTPPort": container_port.to_i,
                    "OriginKeepaliveTimeout": 5,
                    "OriginReadTimeout": 30
                  }
                }
              ],
              "PriceClass": "PriceClass_All",
              "ViewerCertificate": {
                "AcmCertificateArn": :ecs_application_certificate.ref,
                "SslSupportMethod": "sni-only"
              }
            }
          end
          r.property(:tags) do
            [
              {
                "Key": "Environment",
                "Value": environment.to_s
              }
            ]
          end
        end

        resource :application_cloudfront_dns_record,
                 amount: max.to_i.positive? ? 1 : 0,
                 type: "AWS::Route53::RecordSetGroup" do |r|
          r.property(:hosted_zone_id) { :hosted_zone_id.ref }
          r.property(:record_sets) do
            [
              {
                "Name": [name.tr("_", "-"), :hosted_zone_name.ref].fnjoin("."),
                "Type": "A",
                "AliasTarget": {
                  "HostedZoneId": "Z2FDTNDATAQYW2",
                  "DNSName": :cloudfront_distribution.ref(:domain_name)
                }
              }
            ]
          end
        end
      end
    RUBY
  end
end
