require 'fileutils'

FileUtils.mkdir_p 'build'

stacks = {}
Module.constants.select do |mod|
  if mod =~ /Stack$/
    send("include", Object.const_get("SharedConcerns"))
    stacks[mod.to_sym] = send("include", Object.const_get(mod)).render_template
  end
end

stacks.each do |stack_name, stack|
  puts "- Saved #{stack_name} to build/#{stack_name.downcase}.json"
  File.open("build/#{stack_name.downcase}.json", "w") { |f| f.write(stack) }
end
