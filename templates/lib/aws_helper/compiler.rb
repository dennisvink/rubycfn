require "git-revision"

def update_references(contents, environment, _artifact_bucket)
  Dotenv.load(".env.private")
  Dotenv.load(".env.dependencies.#{ENV["ENVIRONMENT"]}")
  contents["Resources"].map do |resource|
    resource_name = resource.shift
    resource_values = resource.shift
    if resource_values["Type"] == "AWS::CloudFormation::Stack"
      template_hash = @stack_hashes[resource_name.to_sym]
      s3_url = "https://s3.amazonaws.com/#{ENV["CLOUDFORMATIONBUCKET"]}/#{environment}-" \
               "#{resource_name.downcase}-#{template_hash}.json"
      resource_values["Properties"]["TemplateURL"] = s3_url
    end
  end
  JSON.pretty_generate(JSON.parse(contents.to_json))
end

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

def compile_stacks(skip_creation = false)
  stacks = {}
  FileUtils.mkdir_p "build" unless skip_creation
  # Iterate twice to support dynamically generated modules
  2.times do
    Module.constants.select do |mod|
      if mod =~ /Stack$/
        next unless stacks[mod.to_sym].nil?
        send("include", Object.const_get("SharedConcerns"))
        stacks[mod.to_sym] = send("include", Object.const_get(mod)).render_template("AWS")
      end
    end
  end

  stacks.each do |stack_name, stack|
    stack = inject_dummy_resource(stack)
    next if JSON.parse(stack)["Resources"].nil?
    stack_to_hash(stack_name)
    unless skip_creation
      puts "- Saved #{stack_name} to build/#{ENV["ENVIRONMENT"]}-#{stack_name.downcase}.json"
      File.open("build/#{ENV["ENVIRONMENT"]}-#{stack_name.downcase}.json", "w") { |f| f.write(JSON.pretty_generate(JSON.parse(stack))) }
    end
  end

  stacks.each do |stack_name, stack|
    stack = inject_dummy_resource(stack)
    next if JSON.parse(stack)["Resources"].nil?
    stack = update_references(JSON.parse(stack), ENV["ENVIRONMENT"], ENV["CLOUDFORMATIONBUCKET"])
    stacks[stack_name] = stack
    stack_to_hash(stack_name)
    unless skip_creation
      File.open("build/#{ENV["ENVIRONMENT"]}-#{stack_name.downcase}.json", "w") { |f| f.write(JSON.pretty_generate(JSON.parse(stack))) }
    end
  end
  stacks
end
