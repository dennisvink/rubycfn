module EcsStack
  module LifecycleHook
    extend ActiveSupport::Concern
    ## Drains instances on termination
    included do
      unless infra_config["environments"][environment]["cluster_size"].nil? || infra_config["environments"][environment]["cluster_size"].to_i.zero?
        resource :ecs_lifecycle_notification_topic,
                 depends_on: :lifecycle_handler_function,
                 type: "AWS::SNS::Topic" do |r|
          r.property(:subscription) do
            [
              {
                "Endpoint": :lifecycle_handler_function.ref(:arn),
                "Protocol": "lambda"
              }
            ]
          end
        end

        resource :instance_terminating_hook,
                 depends_on: :ecs_lifecycle_notification_topic,
                 type: "AWS::AutoScaling::LifecycleHook" do |r|
          r.property(:auto_scaling_group_name) { :ecs_auto_scaling_group.ref }
          r.property(:default_result) { "ABANDON" }
          r.property(:heartbeat_timeout) { 900 }
          r.property(:lifecycle_transition) { "autoscaling:EC2_INSTANCE_TERMINATING" }
          r.property(:notification_target_arn) { :ecs_lifecycle_notification_topic.ref }
          r.property(:role_arn) { :autoscaling_notification_role.ref(:arn) }
        end

        resource :autoscaling_notification_role,
                 type: "AWS::IAM::Role" do |r|
          r.property(:assume_role_policy_document) do
            {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Effect": "Allow",
                  "Principal": {
                    "Service": [
                      "autoscaling.amazonaws.com"
                    ]
                  },
                  "Action": [
                    "sts:AssumeRole"
                  ]
                }
              ]
            }
          end
          r.property(:managed_policy_arns) { ["arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"] }
        end

        resource :lambda_execution_role,
                 type: "AWS::IAM::Role" do |r|
          r.property(:policies) do
            [
              {
                "PolicyName": "lambda-inline",
                "PolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Action": [
                        "autoscaling:CompleteLifecycleAction",
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents",
                        "ec2:DescribeInstances",
                        "ec2:DescribeInstanceAttribute",
                        "ec2:DescribeInstanceStatus",
                        "ec2:DescribeHosts",
                        "ecs:ListContainerInstances",
                        "ecs:SubmitContainerStateChange",
                        "ecs:SubmitTaskStateChange",
                        "ecs:DescribeContainerInstances",
                        "ecs:UpdateContainerInstancesState",
                        "ecs:ListTasks",
                        "ecs:DescribeTasks",
                        "sns:Publish",
                        "sns:ListSubscriptions"
                      ],
                      "Resource": "*"
                    }
                  ]
                }
              }
            ]
          end
          r.property(:assume_role_policy_document) do
            {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Effect": "Allow",
                  "Principal": {
                    "Service": [
                      "lambda.amazonaws.com"
                    ]
                  },
                  "Action": [
                    "sts:AssumeRole"
                  ]
                }
              ]
            }
          end
          r.property(:managed_policy_arns) do
            [
              "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
            ]
          end
        end

        resource :lambda_invoke_permission,
                 type: "AWS::Lambda::Permission" do |r|
          r.property(:function_name) { :lifecycle_handler_function.ref }
          r.property(:action) { "lambda:InvokeFunction" }
          r.property(:principal) { "sns.amazonaws.com" }
          r.property(:source_arn) { :ecs_lifecycle_notification_topic.ref }
        end

        resource :lifecycle_handler_function,
                 type: "AWS::Lambda::Function" do |r|
          r.property(:environment) do
            {
              "Variables": {
                "CLUSTER": :ecs_cluster.ref
              }
            }
          end
          r.property(:code) do
            {
              "ZipFile": {
                "Fn::Join": [
                  "\n",
                  [
                    "import boto3,json,os,time",
                    "ec2Client = boto3.client('ec2')",
                    "ecsClient = boto3.client('ecs')",
                    "autoscalingClient = boto3.client('autoscaling')",
                    "snsClient = boto3.client('sns')",
                    "lambdaClient = boto3.client('lambda')",
                    "def publishSNSMessage(snsMessage,snsTopicArn):",
                    "    response = snsClient.publish(TopicArn=snsTopicArn,Message=json.dumps(snsMessage),Subject='reinvoking')",
                    "def setContainerInstanceStatusToDraining(ecsClusterName,containerInstanceArn):",
                    "    response = ecsClient.update_container_instances_state(cluster=ecsClusterName,containerInstances=[containerInstanceArn],status='DRAINING')",
                    "def tasksRunning(ecsClusterName,ec2InstanceId):",
                    "    ecsContainerInstances = ecsClient.describe_container_instances(cluster=ecsClusterName,containerInstances=ecsClient.list_container_instances(cluster=ecsClusterName)['containerInstanceArns'])['containerInstances']",
                    "    for i in ecsContainerInstances:",
                    "        if i['ec2InstanceId'] == ec2InstanceId:",
                    "            if i['status'] == 'ACTIVE':",
                    "                setContainerInstanceStatusToDraining(ecsClusterName,i['containerInstanceArn'])",
                    "                return 1",
                    "            if (i['runningTasksCount']>0) or (i['pendingTasksCount']>0):",
                    "                return 1",
                    "            return 0",
                    "    return 2",
                    "def lambda_handler(event, context):",
                    "    ecsClusterName=os.environ['CLUSTER']",
                    "    snsTopicArn=event['Records'][0]['Sns']['TopicArn']",
                    "    snsMessage=json.loads(event['Records'][0]['Sns']['Message'])",
                    "    lifecycleHookName=snsMessage['LifecycleHookName']",
                    "    lifecycleActionToken=snsMessage['LifecycleActionToken']",
                    "    asgName=snsMessage['AutoScalingGroupName']",
                    "    ec2InstanceId=snsMessage['EC2InstanceId']",
                    "    checkTasks=tasksRunning(ecsClusterName,ec2InstanceId)",
                    "    if checkTasks==0:",
                    "        try:",
                    "            response = autoscalingClient.complete_lifecycle_action(LifecycleHookName=lifecycleHookName,AutoScalingGroupName=asgName,LifecycleActionToken=lifecycleActionToken,LifecycleActionResult='CONTINUE')",
                    "        except BaseException as e:",
                    "            print(str(e))",
                    "    elif checkTasks==1:",
                    "        time.sleep(5)",
                    "        publishSNSMessage(snsMessage,snsTopicArn)"
                  ]
                ]
              }
            }
          end
          r.property(:handler) { "index.lambda_handler" }
          r.property(:role) { :lambda_execution_role.ref(:arn) }
          r.property(:runtime) { "python3.6" }
          r.property(:timeout) { 10 }
        end
      end
    end
  end
end
