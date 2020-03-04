module InfraStack
  extend ActiveSupport::Concern
  include Rubycfn

  included do
    include Concerns::GlobalVariables
    include Concerns::SharedMethods
    include InfraStack::Parent

    description generate_stack_description("ParentStack")
  end
end
