module EcsStack
  extend ActiveSupport::Concern
  include Rubycfn

  included do
    include Concerns::GlobalVariables
    include Concerns::SharedMethods
    include EcsStack::EcsCluster
    include EcsStack::LifecycleHook
    include EcsStack::LoadBalancer
    include EcsStack::Rollback

    description generate_stack_description("EcsStack")
  end
end
