# Generate nested stacks for each defined application, and create module dynamically.
def create_applications
  resource :applications_stack,
           amount: infra_config["applications"].count,
           type: "AWS::CloudFormation::Stack" do |r, index|
    name = infra_config["applications"].keys[index]
    resource_name = name.tr("-", "_").cfnize
    simple_name = resource_name.downcase
    app_config = infra_config["applications"].values[index]
    warn "App config is empty" unless app_config # Rubocop didn't understand that the variable is actually used.
    #       request_certificate("Gateway", gateway_domains[environment], :asellion_com_hosted_zone_id.ref, "us-east-1")

    r._id("#{resource_name}Stack")
    r.property(:template_url) { "#{simple_name}stack" }
    r.property(:parameters) do
      {
        "Vpc": :vpc_stack.ref("Outputs.SfsVpc"),
        "Cluster": :ecs_stack.ref("Outputs.SfsEcsCluster"),
        "Listener": :ecs_stack.ref("Outputs.EcsLoadBalancerListener"),
        "EcsServiceAutoScalingRoleArn": :ecs_stack.ref("Outputs.SfsEcsAutoScalingRoleArn"),
        "HostedZoneId": :route53_stack.ref("Outputs.HostedZoneId"),
        "HostedZoneName": :route53_stack.ref("Outputs.HostedZoneName"),
        "LoadBalancerDnsName": :ecs_stack.ref("Outputs.EcsLoadBalancerUrl"),
        "CanonicalHostedZoneId": :ecs_stack.ref("Outputs.EcsLoadBalancerHostedZoneId"),
        "CertificateProviderFunctionArn": :acm_stack.ref("Outputs.CertificateProviderFunctionArn")
      }
    end
    Object.const_set("#{resource_name}Stack", Module.new).class_eval <<-RUBY
      extend ActiveSupport::Concern
      include Rubycfn

      included do
        def env_vars_to_array(val)
          vars = []
          val.keys.each_with_index do |object, index|
            vars.push(
              Name: object,
              Value: val.values[index]
            )
          end
          vars
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

        variable :min,
                 value: app_config["min"].to_s

        variable :max,
                 value: app_config["max"].to_s

        variable :container_port,
                 value: app_config["container_port"].to_s

        variable :memory,
                 value: app_config["mem"].to_s

        variable :image,
                 value: app_config["image"]

        variable :env_vars,
                 value: app_config["env"],
                 filter: :env_vars_to_array

        variable :priority,
                 value: app_config["priority"].to_s


        description generate_stack_description("#{resource_name}Stack")
        resource :service,
                 type: "AWS::ECS::Service" do |r|

          r.property(:cluster) { :cluster.ref }
          r.property(:role) { :service_role.ref }
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

        resource :task_definition,
                 type: "AWS::ECS::TaskDefinition" do |r|
          r.property(:family) { "#{simple_name}-service" }
          r.property(:container_definitions) do
            [
              {
                "Name": "#{simple_name}-service",
                "Essential": true,
                "Image": image,
                "Memory": memory.to_i,
                "Environment": env_vars,
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
                 type: "AWS::Logs::LogGroup" do |r|
          r.property(:log_group_name) { ["AWS::StackName".ref, "-#{simple_name}"].fnjoin }
          r.property(:retention_in_days) { 30 }
        end

        resource :target_group,
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
                ]
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
                    }
                  ]
                }
              }
            ]
          end
        end

        resource :application_load_balancer_record,
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
                 type: "AWS::ApplicationAutoScaling::ScalableTarget" do |r|
          r.property(:max_capacity) { max.to_i }
          r.property(:min_capacity) { min.to_i }
          r.property(:resource_id) { ["service", :cluster.ref, :service.ref(:name)].fnjoin("/") }
          r.property(:role_arn) { :ecs_service_auto_scaling_role_arn.ref }
          r.property(:scalable_dimension) { "ecs:service:DesiredCount" }
          r.property(:service_namespace) { "ecs" }
        end

        resource :service_scale_out_policy,
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
                 type: "Custom::Certificate" do |r|
          r.property(:service_token) { :certificate_provider_function_arn.ref }
          r.property(:region) { "us-east-1" }
          r.property(:domain_name) { [name.tr("_", "-"), :hosted_zone_name.ref].fnjoin(".") }
          r.property(:validation_method) { "DNS" }
        end

        resource :ecs_application_issued_certificate,
                 type: "Custom::IssuedCertificate" do |r|
          r.property(:service_token) { :certificate_provider_function_arn.ref }
          r.property(:region) { "us-east-1" }
          r.property(:certificate_arn) { :ecs_application_certificate.ref }
        end

        resource :ecs_application_dns_record,
                 type: "Custom::CertificateDNSRecord" do |r|
          r.property(:service_token) { :certificate_provider_function_arn.ref }
          r.property(:region) { "us-east-1" }
          r.property(:domain_name) { [name.tr("_", "-"), :hosted_zone_name.ref].fnjoin(".") }
          r.property(:certificate_arn) { :ecs_application_certificate.ref }
        end

        resource :ecs_application_validation_record,
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
                 depends_on: :ecs_application_issued_certificate,
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
