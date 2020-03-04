module VpcStack
  extend ActiveSupport::Concern
  include Rubycfn
  included do
    include Concerns::GlobalVariables
    include Concerns::SharedMethods
    include VpcStack::InfraVpc

    description generate_stack_description("VpcStack")
  end
end
