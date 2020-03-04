require "rubycfn"
require "active_support/concern"
require_relative "../spec_helper"
require_relative "../../lib/main.rb"

module ParentSpec
  extend ActiveSupport::Concern
  include Rubycfn

  included do
    description "Infra Stack RSpec"
    include Concerns::GlobalVariables
    include Concerns::SharedMethods
    include InfraStack::Parent
  end
end

ParentSpecCfn = include ParentSpec

describe ParentSpec do
  RspecParentSpec = ParentSpecCfn.render_template
  let(:template) { JSON.parse(RspecParentSpec) }

  context "Renders template" do
    subject { template }
    it { should have_key "Resources" }

    context "Has Required Resources" do
      let(:resources) { template["Resources"] }
      subject { resources }

    end
  end
end
