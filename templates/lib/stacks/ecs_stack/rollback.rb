module EcsStack
  module Rollback
    extend ActiveSupport::Concern
    included do
      resource :application_deployment_failure_rollback_lambda,
               type: "AWS::Lambda::Function" do |r|
        r.property(:code) do
          {
            "S3Bucket": "xebia-${AWS::Region}".fnsub,
            "S3Key": "ecs-rollback-0.0.6.zip"
          }
        end
        r.property(:handler) { "index.lambda_handler" }
        r.property(:role) { :application_deployment_failure_rollback_lambda_role.ref(:arn) }
        r.property(:runtime) { "ruby2.5" }
        r.property(:timeout) { 500 }
      end

      resource :application_deployment_failure_rollback_lambda_role,
               type: "AWS::IAM::Role" do |r|
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
                "Action": "sts:AssumeRole"
              }
            ]
          }
        end
        r.property(:role_name) { "#{environment}-EcsApplicationFailureDetectionRole" }
      end

      resource :application_deployment_failure_rollback_lambda_policy,
               type: "AWS::IAM::Policy" do |r|
        r.property(:policy_document) do
          {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Action": %w(logs:CreateLogGroup logs:CreateLogStream logs:PutLogEvents),
                "Resource": [
                  "arn:aws:logs:*:*:*"
                ]
              },
              {
                "Effect": "Allow",
                "Action": [
                  "ecs:*"
                ],
                "Resource": [
                  "*"
                ]
              }
            ]
          }
        end
        r.property(:policy_name) { "#{environment}-EcsApplicationFailureDetectionPolicy" }
        r.property(:roles) do
          [
            :application_deployment_failure_rollback_lambda_role.ref
          ]
        end
      end

      output :application_deployment_failure_rollback_function_arn,
             value: :application_deployment_failure_rollback_lambda.ref(:arn)
    end
  end
end
