def create_bucket_if_not_exists(aws_region, artifact_bucket)
  s3 = Aws::S3::Resource.new(region: aws_region)
  begin
    s3.create_bucket(bucket: artifact_bucket)
  rescue => exception
    raise exception unless exception.class == Aws::S3::Errors::BucketAlreadyOwnedByYou
  end
  s3
end

def set_aws_credentials(region, access_key_id, secret_access_key)
  if access_key_id.nil? == false && secret_access_key.nil? == false
    aws_session_token = ENV["AWS_SESSION_TOKEN"]
    if aws_session_token.nil?
      Aws.config.update(
        region: region,
        credentials: Aws::Credentials.new(access_key_id, secret_access_key)
      )
    else
      Aws.config.update(
        region: region,
        credentials: Aws::Credentials.new(access_key_id, secret_access_key, aws_session_token)
      )
    end
  else
    Aws.config.update(
      region: region
    )
  end
end
