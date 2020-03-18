require_relative "../core/git"

def upload_stacks
  Dotenv.load(".env.private")
  Dotenv.load(".env.dependencies.#{ENV["ENVIRONMENT"]}")
  env_vars = load_env_vars

  set_aws_credentials(
    env_vars[:aws_region],
    env_vars[:aws_access_key_id],
    env_vars[:aws_secret_access_key]
  )

  begin
    s3 = create_bucket_if_not_exists(
      env_vars[:aws_region],
      env_vars[:artifact_bucket]
    )
  rescue => e
    puts "Exception create_bucket_if_not_exists #{e}"
  end

  stacks = compile_stacks(true)
  raise "CLOUDFORMATIONBUCKET not found in <%= project_name %>#{ENV["ENVIRONMENT"].capitalize}DependencyStack outputs" unless ENV["CLOUDFORMATIONBUCKET"]
  stacks.each do |stack_name, stack|
    next if JSON.parse(stack)["Resources"].nil?
    hash = @stack_hashes[stack_name.to_sym]
    local_file = "#{env_vars[:environment]}-#{stack_name.downcase}.json"
    s3_filename = "#{env_vars[:environment]}-#{stack_name.downcase}-#{hash}.json"
    # content = JSON.parse(stack).to_json
    obj = s3.bucket(ENV["CLOUDFORMATIONBUCKET"]).object(s3_filename)
    content = File.open("build/#{local_file}").read
    obj.put(body: content)
    puts "Uploaded #{stack_name} to s3://#{ENV["CLOUDFORMATIONBUCKET"]}/#{s3_filename}"
  end
end
