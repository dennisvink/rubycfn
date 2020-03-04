def render(file, vars)
  template = File.read(file)
  ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
end

def aws_regions
  [
    { name: "US East (N. Virginia)", value: "us-east-1" },
    { name: "US East (Ohio)", value: "us-east-2" },
    { name: "US West (N. California)", value: "us-west-1" },
    { name: "US West (Oregon)", value: "us-west-2" },
    { name: "Canada (Central)", value: "ca-central-1" },
    { name: "EU (Frankfurt)", value: "eu-central-1" },
    { name: "EU (Ireland)", value: "eu-west-1" },
    { name: "EU (London)", value: "eu-west-2" },
    { name: "EU (Paris)", value: "eu-west-3" },
    { name: "Asia Pacific (Tokyo)", value: "ap-northeast-1" },
    { name: "Asia Pacific (Seoul)", value: "ap-northeast-2" },
    { name: "Asia Pacific (Osaka-Local)", value: "ap-northeast-3" },
    { name: "Asia Pacific (Singapore)", value: "ap-southeast-1" },
    { name: "Asia Pacific (Sydney)", value: "ap-southeast-2" },
    { name: "Asia Pacific (Mumbai)", value: "ap-south-1" },
    { name: "South America (São Paulo)", value: "sa-east-1" }
  ]
end

def rubycfn_banner(version)
  [
    "__________ ____ __________________.___._________ _____________________ ",
    "\\______   \\    |   \\______   \\__  |   |\\_   ___ \\\\_   _____/\\______   \\",
    " |       _/    |   /|    |  _//   |   |/    \\  \\/ |    __)   |    |  _/",
    " |    |   \\    |  / |    |   \\\\____   |\\     \\____|     \\    |    |   \\",
    " |____|_  /______/  |______  // ______| \\______  /\\___  /    |______  /",
    "        \\/                 \\/ \\/               \\/     \\/            \\/ [v#{version}]"
  ].join("\n")
end

def rubycfn_structure(project_name)
  [
    project_name,
    project_name + "/build",
    project_name + "/lib/aws_helper",
    project_name + "/lib/core",
    project_name + "/lib/shared_concerns",
    project_name + "/lib/stacks",
    project_name + "/lib/stacks/ecs_stack",
    project_name + "/lib/stacks/parent_stack",
    project_name + "/lib/stacks/vpc_stack",
    project_name + "/spec",
    project_name + "/spec/lib"
  ]
end

def scaffold_stack
  puts rubycfn_banner(Rubycfn::VERSION)
  raise "Run `rubycfn stack` from project root folder" unless File.file? "lib/stacks/parent_stack/parent.rb"
  prompt = TTY::Prompt.new
  stack_name = prompt.ask("Stack name?", default: "application") do |q|
    q.validate(/^([a-zA-Z]*)$/, "Invalid stack name")
  end
  stack_name = "#{stack_name.downcase}_stack"
  raise "Stack already exists" if File.file? "lib/stacks/#{stack_name}.rb"
  path = File.expand_path(File.dirname(File.dirname(__FILE__)))
  new_stack = render("new_stack.rb", { stack_name: stack_name.split("_").collect(&:capitalize).join }, path)
  new_concern = render("new_concern.rb", { stack_name: stack_name.split("_").collect(&:capitalize).join }, path)
  File.open("lib/stacks/#{stack_name}.rb", "w") { |file| file.write(new_stack) }
  FileUtils.mkdir_p "lib/stacks/#{stack_name}"
  File.open("lib/stacks/#{stack_name}/my_module.rb", "w") { |file| file.write(new_concern) }
  puts "Created stack. Don't forget to add it to lib/stacks/parent_stack/parent.rb !"
  exit
end
