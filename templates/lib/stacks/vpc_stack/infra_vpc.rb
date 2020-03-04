module VpcStack
  module InfraVpc
    extend ActiveSupport::Concern
    included do
      vpc_subnets = infra_config["subnets"]

      variable :cidr_block,
               default: "10.0.0.0/16",
               value: infra_config["environments"][environment]["vpc_cidr"]

      resource :infra_vpc,
               type: "AWS::EC2::VPC" do |r|
        r.property(:cidr_block) { cidr_block }
        r.property(:enable_dns_support) { true }
        r.property(:enable_dns_hostnames) { true }
        r.property(:tags) do
          [
            {
              "Key": "Name",
              "Value": "infra_#{environment}_vpc"
            },
            {
              "Key": "Environment",
              "Value": environment.to_s
            }
          ]
        end
      end

      resource :infra_internet_gateway,
               type: "AWS::EC2::InternetGateway"

      resource :infra_route,
               type: "AWS::EC2::Route" do |r|
        r.property(:destination_cidr_block) { "0.0.0.0/0" }
        r.property(:gateway_id) { :infra_internet_gateway.ref }
        r.property(:route_table_id) { :infra_route_table.ref }
      end

      resource :infra_route_table,
               type: "AWS::EC2::RouteTable" do |r|
        r.property(:vpc_id) { :infra_vpc.ref }
        r.property(:tags) do
          [
            {
              "Key": "Name",
              "Value": "Infra #{environment} Public Route Table"
            },
            {
              "Key": "Environment",
              "Value": environment.to_s
            }
          ]
        end
      end

      resource :infra_private_route_table,
               amount: 3,
               type: "AWS::EC2::RouteTable" do |r, index|
        r.property(:vpc_id) { :infra_vpc.ref }
        r.property(:tags) do
          [
            {
              "Key": "Name",
              "Value": "Infra #{environment} Private Route Table #{index.zero? && "" || index + 1}"
            },
            {
              "Key": "Environment",
              "Value": environment.to_s
            }
          ]
        end
      end

      resource :infra_vpc_gateway_attachment,
               type: "AWS::EC2::VPCGatewayAttachment" do |r|
        r.property(:internet_gateway_id) { :infra_internet_gateway.ref }
        r.property(:vpc_id) { :infra_vpc.ref }
      end

      vpc_subnets.each_with_index do |subnet, _subnet_count|
        subnet.each do |subnet_name, arguments|
          resource "infra_#{subnet_name}_subnet".cfnize,
                   type: "AWS::EC2::Subnet",
                   amount: 3 do |r, index|
            subnet_cidr = [
              :infra_vpc.ref(:cidr_block),
              (3 * arguments["offset"]).to_s,
              (Math.log(256) / Math.log(2)).floor.to_s
            ].fncidr.fnselect(index + (3 * arguments["offset"]) - 3)

            r.property(:availability_zone) do
              {
                "Fn::GetAZs": ""
              }.fnselect(index)
            end
            r.property(:cidr_block) { subnet_cidr }
            r.property(:map_public_ip_on_launch) { arguments["public"] }
            r.property(:tags) do
              [
                {
                  "Key": "Name",
                  "Value": "#{environment}_#{subnet_name}_#{index + 1}".cfnize
                },
                {
                  "Key": "Team",
                  "Value": arguments["owner"]
                },
                {
                  "Key": "resource_type",
                  "Value": subnet_name.to_s.cfnize
                }
              ]
            end
            r.property(:vpc_id) { :infra_vpc.ref }

            if arguments["output_cidr"]
              cidr_output_name = "#{subnet_name}_subnet#{index.positive? ? (index + 1) : ""}_cidr".cfnize

              output cidr_output_name,
                     value: subnet_cidr
            end
          end

          if arguments["public"]
            resource "infra_#{subnet_name}_subnet_route_table_association".cfnize,
                     amount: 3,
                     type: "AWS::EC2::SubnetRouteTableAssociation" do |r, index|
              r.property(:route_table_id) { :infra_route_table.ref }
              r.property(:subnet_id) { "infra_#{subnet_name}_subnet#{index.zero? && "" || index + 1}".cfnize.ref }
            end
          else
            resource "infra_#{subnet_name}_subnet_route_table_association".cfnize,
                     amount: 3,
                     type: "AWS::EC2::SubnetRouteTableAssociation" do |r, index|
              r.property(:route_table_id) { "infra_private_route_table#{index.zero? && "" || index + 1}".cfnize.ref }
              r.property(:subnet_id) { "infra_#{subnet_name}_subnet#{index.zero? && "" || index + 1}".cfnize.ref }
            end
          end

          # Generate outputs for these subnets
          3.times do |i|
            output_name = "#{subnet_name}_subnet#{i.positive? ? (i + 1) : ""}_name".cfnize

            output output_name,
                   value: "infra_#{subnet_name}_subnet#{i.positive? ? (i + 1) : ""}".cfnize.ref
          end

          # Deploy NAT Gateway in subnet marked with "deploy_nat": true
          if arguments["deploy_nat"]
            resource "infra_#{subnet_name}_elastic_ip".cfnize,
                     amount: 3,
                     type: "AWS::EC2::EIP" do |r, _|
              r.property(:domain) { "vpc" }
            end

            resource "infra_#{subnet_name}_nat_gateway".cfnize,
                     amount: 3,
                     type: "AWS::EC2::NatGateway" do |r, index|
              r.property(:allocation_id) { "infra_#{subnet_name}_elastic_ip#{index.zero? && "" || index + 1}".cfnize.ref(:allocation_id) }
              r.property(:subnet_id) { "infra_#{subnet_name}_subnet#{index.zero? && "" || index + 1}".cfnize.ref }
            end

            resource :infra_nat_gateway_route,
                     depends_on: :infra_vpc_gateway_attachment,
                     amount: 3,
                     type: "AWS::EC2::Route" do |r, index|
              r.depends_on [
                "InfraEc2PublicNatGateway#{index.zero? && "" || index + 1}"
              ]
              r.property(:destination_cidr_block) { "0.0.0.0/0" }
              r.property(:nat_gateway_id) { "infra_#{subnet_name}_nat_gateway#{index.zero? && "" || index + 1}".cfnize.ref }
              r.property(:route_table_id) { "infra_private_route_table#{index.zero? && "" || index + 1}".cfnize.ref }
            end

            # Generate outputs for NAT gateway
            3.times do |i|
              output_name = "nat_gateway_#{subnet_name}#{i.positive? ? (i + 1) : ""}"

              output output_name,
                     value: "infra_#{subnet_name}_nat_gateway#{i.positive? ? (i + 1) : ""}".cfnize.ref
            end
          end
        end
      end

      output :vpc_cidr,
             value: :infra_vpc.ref(:cidr_block)
      output :vpc_id,
             value: :infra_vpc.ref
    end
  end
end
