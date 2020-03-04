WAITING_STATES = %w(
  CREATE_IN_PROGRESS DELETE_IN_PROGRESS ROLLBACK_IN_PROGRESS
  UPDATE_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_IN_PROGRESS
  UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS UPDATE_ROLLBACK_IN_PROGRESS
).freeze
SUCCESS_STATES = %w(IMPORT_COMPLETE CREATE_COMPLETE UPDATE_COMPLETE).freeze
FAILURE_STATES = %w(
  CREATE_FAILED DELETE_FAILED UPDATE_ROLLBACK_FAILED
  ROLLBACK_FAILED ROLLBACK_COMPLETE ROLLBACK_FAILED
  UPDATE_ROLLBACK_COMPLETE UPDATE_ROLLBACK_FAILED
).freeze
END_STATES = SUCCESS_STATES + FAILURE_STATES
DEPLOYABLE_STATES = %w(
  IMPORT_COMPLETE CREATE_COMPLETE UPDATE_COMPLETE ROLLBACK_COMPLETE
  UPDATE_ROLLBACK_COMPLETE
).freeze

# Method to retrieve paste CF events.
# Arguments: Aws::Client and stack name
def get_prior_events(client, stack_name)
  client.describe_stack_events(
    stack_name: stack_name
  ).stack_events.to_a
rescue => exception
  raise exception unless exception.class == Aws::CloudFormation::Errors::ValidationError
  []
end

def get_events_last_deploy(previous_events)
  initiated = false
  previous_events.map do |event|
    initiated = true if event.resource_status_reason == "User Initiated"
    initiated ? nil : event
  end.to_a.compact
end

# Method to predict location of the s3 CloudFormation artifact
def get_parent_stack_s3_location(bucket, environment)
  stacks = compile_stacks(true)
  parent_stack = nil
  file_hash = nil

  stacks.each do |stack_name, stack|
    next if JSON.parse(stack)["Resources"].nil?
    JSON.parse(stack)["Resources"].each do |_resource, payload|
      if payload["Type"] == "AWS::CloudFormation::Stack"
        parent_stack = stack_name
        file_hash = git_revision
        break
      end
    end
  end
  "https://s3.amazonaws.com/#{bucket}/#{environment}-#{parent_stack.downcase}-#{file_hash}.json"
end
