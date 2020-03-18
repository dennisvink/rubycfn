module EcsStack
  module EcsCluster
    extend ActiveSupport::Concern
    included do
      parameter :vpc,
                description: "VPC ID"
      parameter :subnets,
                description: "Subnets for ECS"
      parameter :ecs_ami,
                description: "ECS-Optimized AMI ID",
                type: "AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>",
                default: "/aws/service/ecs/optimized-ami/amazon-linux/recommended/image_id"

      variable :cluster_size,
               default: "1",
               value: infra_config["environments"][environment]["cluster_size"]

      variable :cluster_instance_type,
               default: "t2.micro",
               value: infra_config["environments"][environment]["cluster_instance_type"]

      resource :ecs_cluster,
               type: "AWS::ECS::Cluster"

      unless infra_config["environments"][environment]["cluster_size"].nil? || infra_config["environments"][environment]["cluster_size"].to_i.zero?
        resource :ecs_auto_scaling_group,
                 type: "AWS::AutoScaling::AutoScalingGroup" do |r|
          r.property(:vpc_zone_identifier) { :subnets.ref.fnsplit(",") }
          r.property(:launch_configuration_name) { :ecs_launch_configuration.ref }
          r.property(:min_size) { cluster_size.to_i }
          r.property(:max_size) { cluster_size.to_i + 1 }
          r.property(:desired_capacity) { cluster_size.to_i }
          r.property(:tags) do
            [
              {
                "Key": "Name",
                "Value": "#{environment} ECS host",
                "PropagateAtLaunch": true
              }
            ]
          end
        end

        resource :ecs_launch_configuration,
                 metadata: {
                   "AWS::CloudFormation::Init": {
                     "config": {
                       "packages": {
                         "yum": {
                           "collectd": []
                         }
                       },
                       "commands": {
                         "01_add_instance_to_cluster": {
                           "command": "echo ECS_CLUSTER=${EcsCluster} >> /etc/ecs/ecs.config".fnsub
                         },
                         "02_enable_cloudwatch_agent": {
                           "command": "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c ssm:${EcsCloudWatchParameter} -s".fnsub
                         }
                       },
                       "files": {
                         "/etc/cfn/cfn-hup.conf": {
                           "mode": 256,
                           "owner": "root",
                           "group": "root",
                           "content": "[main]\nstack=${AWS::StackId}\nregion=${AWS::Region}\n".fnsub
                         },
                         "/etc/cfn/hooks.d/cfn-auto-reloader.conf": {
                           "content": "[cfn-auto-reloader-hook]\ntriggers=post.update\npath=Resources.EcsLaunchConfiguration.Metadata.AWS::CloudFormation::Init\naction=/opt/aws/bin/cfn-init -v --region ${AWS::Region} --stack ${AWS::StackName} --resource EcsLaunchConfiguration\n".fnsub
                         }
                       },
                       "services": {
                         "sysvinit": {
                           "cfn-hup": {
                             "enabled": true,
                             "ensureRunning": true,
                             "files": [
                               "/etc/cfn/cfn-hup.conf",
                               "/etc/cfn/hooks.d/cfn-auto-reloader.conf"
                             ]
                           }
                         }
                       }
                     }
                   }
                 },
                 type: "AWS::AutoScaling::LaunchConfiguration" do |r|
          r.property(:image_id) { :ecs_ami.ref }
          r.property(:instance_type) { cluster_instance_type }
          r.property(:security_groups) do
            [
              :ecs_host_security_group.ref,
              :load_balancer_security_group.ref # Not sure if necessary
            ]
          end
          r.property(:iam_instance_profile) { :ecs_instance_profile.ref }
          r.property(:user_data) { "#!/bin/bash\nyum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm\nyum install -y https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm\nyum install -y aws-cfn-bootstrap hibagent \n/opt/aws/bin/cfn-init -v --region ${AWS::Region} --stack ${AWS::StackName} --resource EcsLaunchConfiguration\n/opt/aws/bin/cfn-signal -e $? --region ${AWS::Region} --stack ${AWS::StackName} --resource EcsAutoScalingGroup\n/usr/bin/enable-ec2-spot-hibernation\n".fnsub.fnbase64 }
        end

        ecs_ssm_parameter_value = {
          "logs": {
            "force_flush_interval": 5,
            "logs_collected": {
              "files": {
                "collect_list": [
                  {
                    "file_path": "/var/log/messages",
                    "log_group_name": "${EcsCluster}-/var/log/messages",
                    "log_stream_name": "{instance_id}",
                    "timestamp_format": "%b %d %H:%M:%S"
                  },
                  {
                    "file_path": "/var/log/dmesg",
                    "log_group_name": "${EcsCluster}-/var/log/dmesg",
                    "log_stream_name": "{instance_id}"
                  },
                  {
                    "file_path": "/var/log/docker",
                    "log_group_name": "${EcsCluster}-/var/log/docker",
                    "log_stream_name": "{instance_id}",
                    "timestamp_format": "%Y-%m-%dT%H:%M:%S.%f"
                  },
                  {
                    "file_path": "/var/log/ecs/ecs-init.log",
                    "log_group_name": "${EcsCluster}-/var/log/ecs/ecs-init.log",
                    "log_stream_name": "{instance_id}",
                    "timestamp_format": "%Y-%m-%dT%H:%M:%SZ"
                  },
                  {
                    "file_path": "/var/log/ecs/ecs-agent.log.*",
                    "log_group_name": "${EcsCluster}-/var/log/ecs/ecs-agent.log",
                    "log_stream_name": "{instance_id}",
                    "timestamp_format": "%Y-%m-%dT%H:%M:%SZ"
                  },
                  {
                    "file_path": "/var/log/ecs/audit.log",
                    "log_group_name": "${EcsCluster}-/var/log/ecs/audit.log",
                    "log_stream_name": "{instance_id}",
                    "timestamp_format": "%Y-%m-%dT%H:%M:%SZ"
                  }
                ]
              }
            }
          },
          "metrics": {
            "append_dimensions": {
              "AutoScalingGroupName": "${!aws:AutoScalingGroupName}",
              "InstanceId": "${!aws:InstanceId}",
              "InstanceType": "${!aws:InstanceType}"
            },
            "metrics_collected": {
              "collectd": {
                "metrics_aggregation_interval": 60
              },
              "disk": {
                "measurement": [
                  "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                  "/"
                ]
              },
              "mem": {
                "measurement": [
                  "mem_used_percent"
                ],
                "metrics_collection_interval": 60
              },
              "statsd": {
                "metrics_aggregation_interval": 60,
                "metrics_collection_interval": 10,
                "service_address": ":8125"
              }
            }
          }
        }

        resource :ecs_cloud_watch_parameter,
                 type: "AWS::SSM::Parameter" do |r|
          r.property(:description) { "ECS" }
          r.property(:name) { "AmazonCloudWatch-${EcsCluster}-ECS".fnsub }
          r.property(:type) { "String" }
          r.property(:value) { JSON.pretty_generate(ecs_ssm_parameter_value).fnsub }
        end

        resource :ecs_host_security_group,
                 type: "AWS::EC2::SecurityGroup" do |r|
          r.property(:vpc_id) { :vpc.ref }
          r.property(:group_description) { "Access to the ECS hosts and the tasks/containers that run on them" }
          r.property(:security_group_ingress) do
            [
              {
                "SourceSecurityGroupId": :load_balancer_security_group.ref,
                "IpProtocol": -1
              }
            ]
          end
          r.property(:tags) do
            [
              {
                "Key": "Name",
                "Value": "#{environment}-ECS-Hosts"
              }
            ]
          end
        end

        resource :load_balancer_security_group,
                 type: "AWS::EC2::SecurityGroup" do |r|
          r.property(:vpc_id) { :vpc.ref }
          r.property(:group_description) { "Access to the load balancer that sits in front of ECS" }
          r.property(:security_group_ingress) do
            [
              {
                "CidrIp": "0.0.0.0/0",
                "IpProtocol": -1
              }
            ]
          end
          r.property(:tags) do
            [
              {
                "Key": "Name",
                "Value": "#{environment}-ECS-LoadBalancers"
              }
            ]
          end
        end

        ecs_role_assume_role_policy_document = {
          "Statement": [
            {
              "Action": "sts:AssumeRole",
              "Effect": "Allow",
              "Principal": {
                "Service": "ec2.amazonaws.com"
              }
            }
          ]
        }

        ecs_role_policy_document = {
          "Statement": [{
            "Effect": "Allow",
            "Action": [
              "ecs:CreateCluster",
              "ecs:DeregisterContainerInstance",
              "ecs:DiscoverPollEndpoint",
              "ecs:Poll",
              "ecs:RegisterContainerInstance",
              "ecs:StartTelemetrySession",
              "ecs:Submit*",
              "ecr:BatchCheckLayerAvailability",
              "ecr:BatchGetImage",
              "ecr:GetDownloadUrlForLayer",
              "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
          }]
        }

        resource :ecs_role,
                 type: "AWS::IAM::Role" do |r|
          r.property(:path) { "/" }
          r.property(:role_name) { "#{environment}-ECSRole-${AWS::Region}".fnsub }
          r.property(:assume_role_policy_document) { JSON.pretty_generate(ecs_role_assume_role_policy_document) }
          r.property(:managed_policy_arns) do
            [
              "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM",
              "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
              "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
            ]
          end
          r.property(:policies) do
            [
              {
                "PolicyName": "ecs-service",
                "PolicyDocument": JSON.pretty_generate(ecs_role_policy_document)
              }
            ]
          end
        end

        resource :ecs_instance_profile,
                 type: "AWS::IAM::InstanceProfile" do |r|
          r.property(:path) { "/" }
          r.property(:roles) do
            [
              :ecs_role.ref
            ]
          end
        end

        resource :ecs_service_auto_scaling_role,
                 type: "AWS::IAM::Role" do |r|
          r.property(:assume_role_policy_document) do
            {
              "Version": "2012-10-17",
              "Statement": {
                "Action": [
                  "sts:AssumeRole"
                ],
                "Effect": "Allow",
                "Principal": {
                  "Service": [
                    "application-autoscaling.amazonaws.com"
                  ]
                }
              }
            }
          end
          r.property(:path) { "/" }
          r.property(:policies) do
            [
              {
                "PolicyName": "ecs-service-autoscaling",
                "PolicyDocument": {
                  "Statement": {
                    "Effect": "Allow",
                    "Action": [
                      "application-autoscaling:*",
                      "cloudwatch:DescribeAlarms",
                      "cloudwatch:PutMetricAlarm",
                      "ecs:DescribeServices",
                      "ecs:UpdateService"
                    ],
                    "Resource": "*"
                  }
                }
              }
            ]
          end
        end
        output :ecs_auto_scaling_role_arn,
               value: :ecs_service_auto_scaling_role.ref(:arn)
      end
      output :ecs_cluster,
             value: :ecs_cluster.ref
      output :ecs_cluster_arn,
             value: :ecs_cluster.ref(:arn)
    end
  end
end
