module AcmStack
  module CertificateManager
    extend ActiveSupport::Concern
    included do
      resource :certificate_provider_function,
               type: "AWS::Lambda::Function" do |r|
        r.property(:code) do
          {
            "S3Bucket": "xebia-${AWS::Region}".fnsub,
            "S3Key": "cfn-certificate-provider-0.2.4.zip"
          }
        end
        r.property(:handler) { "provider.handler" }
        r.property(:role) { :lambda_execution_role.ref(:arn) }
        r.property(:runtime) { "python3.6" }
        r.property(:memory_size) { 128 }
        r.property(:timeout) { 300 }
      end

      resource :lambda_execution_role,
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
                "Action": [
                  "sts:AssumeRole"
                ]
              }
            ]
          }
        end
        r.property(:path) { "/" }
        r.property(:policies) do
          [
            {
              "PolicyName": "CertificateProviderExecutionRole",
              "PolicyDocument": {
                "Version": "2012-10-17",
                "Statement": [
                  {
                    "Effect": "Allow",
                    "Resource": "*",
                    "Action": [
                      "acm:RequestCertificate",
                      "acm:DescribeCertificate",
                      "acm:UpdateCertificateOptions",
                      "acm:DeleteCertificate"
                    ]
                  },
                  {
                    "Effect": "Allow",
                    "Action": "lambda:InvokeFunction",
                    "Resource": "arn:aws:lambda:${AWS::Region}:${AWS::AccountId}:function:*".fnsub
                  },
                  {
                    "Effect": "Allow",
                    "Action": %w(logs:CreateLogGroup logs:CreateLogStream logs:PutLogEvents),
                    "Resource": "arn:aws:logs:*:*:*"
                  }
                ]
              }
            }
          ]
        end
      end

      output :certificate_provider_function_arn,
             value: :certificate_provider_function.ref(:arn)
    end
  end
end
