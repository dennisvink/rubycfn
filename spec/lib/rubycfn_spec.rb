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
        r.property(:security_group_id) { :rspec_security_group.ref }
        r.property(:some_other_ref) { "rSpecSecurityGroup".ref }
        r.property(:some_arn) { :rspec_resource.ref(:arn) }
        r.property(:some_other_arn) { :rspec_resource.ref("FooBar") }
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

        context "has correct properties" do
          let(:properties) { resource["Properties"] }
          subject { properties }

          it { should have_key "Name" }
          it { should have_key "SecurityGroupId" }
          it { should have_key "SomeOtherRef" }
          it { should have_key "SomeArn" }
          it { should have_key "SomeOtherArn" }

          context "ref symbol is rendered correctly" do
            let(:ref_symbol) { properties["SecurityGroupId"] }
            subject { ref_symbol }

            it { should eq JSON.parse({ Ref: "RspecSecurityGroup" }.to_json) }
          end

          context "ref string is rendered correctly" do
            let(:ref_string) { properties["SomeOtherRef"] }
            subject { ref_string }

            it { should eq JSON.parse({ Ref: "rSpecSecurityGroup" }.to_json) }
          end

          context "Fn:GetAtt with symbol is rendered correctly" do
            let(:fngetatt_symbol) { properties["SomeArn"] }
            subject { fngetatt_symbol }

            it { should eq JSON.parse({ "Fn::GetAtt": ["RspecResource", "Arn"] }.to_json) }
          end

          context "Fn:GetAtt with string is rendered correctly" do
            let(:fngetatt_string) { properties["SomeOtherArn"] }
            subject { fngetatt_string }

            it { should eq JSON.parse({ "Fn::GetAtt": ["RspecResource", "FooBar"] }.to_json) }
          end
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

          it { should eq JSON.parse({ AutoScalingReplacingUpdate: { WillReplace: true }}.to_json) }
        end
      end
    end
  end
end
