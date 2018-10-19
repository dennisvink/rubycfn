module RubyCfn
  module VPC
    def self.[](prefix, suffix, &block)
      Module.new do
        extend ActiveSupport::Concern

        included do

          def validate_instance_tenancy(value)
            unless ["", 'default', 'dedicated'].include? value
              raise "Expected instance_tenancy to be within `default` or `dedicated`. Received `#{value}`"
            end
            value
          end

          variable :cidr_block,
                   default: "10.0.0.0/16" 
          variable :enable_dns_support,
                   default: true
          variable :enable_dns_hostnames,
                   default: true
          variable :instance_tenancy,
                   filter: :validate_instance_tenancy

          # TODO: Move to separate compound resource
          # variable :ipv6,
          #          default: false
          # variable :subnets,
          #          default: 3
          # variable :subnet_ip_addresses,
          #          default: 256

          yield self if block_given? # Variable overrides

          resource "#{prefix}_vpc#{suffix}".cfnize,
                   type: "AWS::EC2::VPC" do |r, index|
            r.property(:cidr_block) { cidr_block }
            r.property(:enable_dns_support) { enable_dns_support }
            r.property(:enable_dns_hostnames) { enable_dns_hostnames }
            r.property(:instance_tenancy) { instance_tenancy } unless instance_tenancy.empty?
          end

          resource "#{prefix}_internet_gateway#{suffix}".cfnize,
                   type: "AWS::EC2::InternetGateway"

          resource "#{prefix}_route#{suffix}".cfnize,
                   type: "AWS::EC2::Route" do |r, index|
            r.property(:destination_cidr_block) { "0.0.0.0/0" }
            r.property(:gateway_id) { "#{prefix}_internet_gateway#{suffix}".cfnize.ref }
            r.property(:route_table_id) { "#{prefix}_route_table#{suffix}".cfnize.ref }
          end

          resource "#{prefix}_route_table#{suffix}.cfnize",
                   type: "AWS::EC2::RouteTable" do |r, index|
            r.property(:vpc_id) { "#{prefix}_vpc#{suffix}".cfnize.ref }
          end

          resource "#{prefix}_vpc_gateway_attachment#{suffix}".cfnize,
                   type: "AWS::EC2::VPCGatewayAttachment" do |r, index|
            r.property(:internet_gateway_id) { "#{prefix}_internet_gateway#{suffix}".cfnize.ref }
            r.property(:vpc_id) { "#{prefix}_vpc#{suffix}".cfnize.ref }
          end

          # TODO: Move to separate compound resource
          #subnets.times do |i|
          #  resource "#{prefix}_subnet#{suffix}#{i == 0 ? "" : i+1}",
          #           type: "AWS::EC2::Subnet",
          #           compound: true do |r, index|
          #    r.property(:vpc_id) { "#{prefix}_vpc#{suffix}".cfnize.ref }
          #    r.property(:cidr_block) { ["#{prefix}_vpc#{suffix}".cfnize.ref("CidrBlock"), subnets.to_s, ((Math.log(subnet_ip_addresses)/Math.log(2)).floor).to_s].fncidr.fnselect(i) }
          #    #if ipv6 == "true"
          #    #  r.property(:ipv6_cidr_block) do
          #    #    .. todo ..
          #    #  end
          #    #end
          #  end
          #end

          #if ipv6 == "true"
          #  resource "#{prefix}_ipv6_cidr_block#{suffix}",
          #           type: "AWS::EC2::VPCCidrBlock" do |r, index|
          #    r.property(:vpc_id) { "#{prefix}_vpc#{suffix}".cfnize.ref }
          #    r.property(:amazon_provided_ipv6_cidr_block) { true }
          #  end
          #end
        end
      end
    end
  end
end
