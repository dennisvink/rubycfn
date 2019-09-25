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
               amount: 2 do |r, index|
        r.depends_on [ "barFoo", :bar_foo ] unless index.positive?
        r.property(:name) { "RSpec" }
        r.property(:security_group_id) { :rspec_security_group.ref }
        r.property(:some_other_ref) { "rSpecSecurityGroup".ref }
        r.property(:some_arn) { :rspec_resource.ref(:arn) }
        r.property(:some_other_arn) { :rspec_resource.ref("FooBar") }
      end

      resource :asellion_com_database_instance,
               type: "AWS::RDS::DBInstance" do |r|
        r.property(:db_instance_identifier) { "rspec" }
        r.property(:allocated_storage) { 100 }
        r.property(:dbinstanceclass) { "db.t2.small" }
        r.property(:engine) { "mariadb" }
        r.property(:master_username) { "rspecroot" }
        r.property(:master_user_password) { "rubycfn<3" }
        r.property(:db_name) { "MyAwesomeDatabase" }
        r.property(:preferred_backup_window) { "01:00-01:30" }
        r.property(:backup_retention_period) { 14 }
        r.property(:availability_zone) { "eu-central-1b" }
        r.property(:preferred_maintenance_window) { "sun:06:00-sun:06:30" }
        r.property(:multi_az) { true }
        r.property(:engine_version) { "10.1.34" }
        r.property(:auto_minor_version_upgrade) { true }
        r.property(:license_model) { "general-public-license" }
        r.property(:publicly_accessible) { true }
        r.property(:storage_type) { "gp2" }
        r.property(:port) { 3306 }
        r.property(:copy_tags_to_snapshot) { true }
        r.property(:monitoring_interval) { 60 }
        r.property(:enable_iam_database_authentication) { false }
        r.property(:enable_performance_insights) { false }
        r.property(:deletion_protection) { true }
        r.property(:db_subnet_group_name) { "default-vpc-123456789" }
        r.property(:vpc_security_groups) do
          [
            "sg-0xc0ff3e"
          ]
        end
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
      it { should have_key "RspecResourceName2" }
      it { should_not have_key "RspecResourceName3" }

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
      context "second resource does not have depends_on" do
        let(:resource) { resources["RspecResourceName2"] }
        subject { resource }

        it { should have_key "DependsOn" }
        it { should have_key "Type" }
        it { should have_key "Properties" }
        it { should have_key "UpdatePolicy"}

        context "second resource renders only the initial depends_on resources" do
          let(:depends_on)  { resource["DependsOn"] }
          subject { depends_on }

          it { should eq ["FooBar", "fooBar"] }
        end
      end

      context "Database resource exists" do
        subject { resources }

        it { should have_key "AsellionComDatabaseInstance" }

        context "Database resource has the right autocorrected properties" do
          let(:properties) { resources["AsellionComDatabaseInstance"]["Properties"] }
          subject { properties }

          it { should have_key "DBInstanceClass" }
          it { should have_key "DBInstanceIdentifier" }
          it { should have_key "DBName" }
          it { should have_key "DBSubnetGroupName" }
          it { should have_key "MultiAZ" }
          it { should have_key "VPCSecurityGroups" }
        end
      end
    end
  end
end
