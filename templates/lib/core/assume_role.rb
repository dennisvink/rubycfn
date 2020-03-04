require "aws-sdk-core"
require "aws-sdk-s3"
require "aws-sdk-iam"
require "aws-sdk-organizations"

def generate_session_name
  "assume_role_" + (0...12).map { ("a".."z").to_a[rand(26)] }.join
end

def assume_role(aws_accounts, to_account, from_account = nil)
  session_name = generate_session_name
  if from_account
    from_credentials = aws_accounts[from_account][:credentials]
    credentials = Aws::AssumeRoleCredentials.new(
      client: Aws::STS::Client.new(
        access_key_id: from_credentials[:access_key_id],
        region: "eu-central-1",
        secret_access_key: from_credentials[:secret_access_key],
        session_token: from_credentials[:session_token]
      ),
      role_arn: "arn:aws:iam::#{aws_accounts[to_account][:account_id]}:role/#{aws_accounts[to_account][:role_name]}",
      role_session_name: session_name
    )
  else
    credentials = Aws::AssumeRoleCredentials.new(
      client: Aws::STS::Client.new(region: aws_accounts[to_account][:region]),
      role_arn: "arn:aws:iam::#{aws_accounts[to_account][:account_id]}:role/#{aws_accounts[to_account][:role_name]}",
      role_session_name: session_name
    )
  end
  aws_accounts[to_account][:credentials] = {
    access_key_id: credentials.credentials.access_key_id,
    credentials: credentials,
    region: aws_accounts[to_account][:region],
    secret_access_key: credentials.credentials.secret_access_key,
    session_name: session_name,
    session_token: credentials.credentials.session_token
  }
  aws_accounts
end
