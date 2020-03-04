module AcmStack
  extend ActiveSupport::Concern
  include Rubycfn
  included do
    include Concerns::GlobalVariables
    include Concerns::SharedMethods
    include AcmStack::CertificateManager

    description generate_stack_description("AcmStack")
  end
end
