require "spec_helper"

require "rubycfn"
require "active_support/concern"

describe Rubycfn do

  module RspecStack
    extend ActiveSupport::Concern
    include Rubycfn

    included do
      description "RSpec Test Stack"

      resource :rspec_resource_name,
               depends_on: [:foo_bar,"fooBar"],
               type: "Rspec::Test",
               update_policy: {
                 "AutoScalingReplacingUpdate": {
                   "WillReplace": true
                 }
               },
               amount: 2 do |r|
        r.depends_on [ "barFoo", :bar_foo ]
        r.property(:name) { "RSpec" }
      end
    end
  end

  CloudFormation = include RspecStack
  RspecStack = CloudFormation.render_template
  Given(:json) { JSON.parse(RspecStack) }

  context "renders template" do
    let(:template) { json }
    subject { template }

    it { should_not have_key 'Parameters' }
    it { should_not have_key 'Outputs' }

    it { should have_key 'Description' }
    it { should have_key 'Resources' }
    it { should have_key 'AWSTemplateFormatVersion' }

    context "has description" do
      let(:description) { template["Description"] }
      subject { description }

      it { should eq "RSpec Test Stack" }
    end

    context "created resource" do
      let(:resources) { template["Resources"] }
      subject { resources }

      it { should have_key "RspecResourceName" }

      context "has resource type" do
        let(:resource) { resources["RspecResourceName"] }
        subject { resource }

        it { should have_key "DependsOn" }
        it { should have_key "Type" }
        it { should have_key "Properties" }
        it { should have_key "UpdatePolicy"}

        context "depends_on is rendered correctly" do
          let(:depends_on)  { resource["DependsOn"] }
          subject { depends_on }

          it { should eq ["FooBar", "fooBar", "barFoo", "BarFoo"] }
        end

        context "resource type is correct" do
          let(:type) { resource["Type"] }
          subject { type }

          it { should eq "Rspec::Test" }
        end

        context "has name property" do
          let(:properties) { resource["Properties"] }
          subject { properties }

          it { should have_key "Name" }
        end

        context "Update policy is correct" do
          let(:update_policy) { resource["UpdatePolicy"] }
          subject { update_policy }

          it { should include("AutoScalingReplacingUpdate" => { "WillReplace" => true })}
        end
      end
    end
  end
end
