module EcsStack
  module LoadBalancer
    extend ActiveSupport::Concern
    included do
      parameter :public_subnets,
                description: "List of Public EC2 Subnets for the ALB"

      unless infra_config["environments"][environment]["cluster_size"].nil? || infra_config["environments"][environment]["cluster_size"].to_i.zero?
        resource :ecs_load_balancer,
                 type: "AWS::ElasticLoadBalancingV2::LoadBalancer" do |r|
          r.property(:name) { environment }
          r.property(:subnets) { :public_subnets.ref.fnsplit(",") }
          r.property(:security_groups) do
            [
              :ecs_host_security_group.ref,
              :load_balancer_security_group.ref # Not sure if necessary
            ]
          end
          r.property(:tags) do
            [
              {
                "Key": "Name",
                "Value": "#{environment}_ecs_loadbalancer"
              }
            ]
          end
        end

        resource :load_balancer_listener,
                 type: "AWS::ElasticLoadBalancingV2::Listener" do |r|
          r.property(:load_balancer_arn) { :ecs_load_balancer.ref }
          r.property(:port) { 80 }
          r.property(:protocol) { "HTTP" }
          r.property(:default_actions) do
            [
              {
                "Type": "forward",
                "TargetGroupArn": :default_target_group.ref
              }
            ]
          end
        end

        resource :default_target_group,
                 type: "AWS::ElasticLoadBalancingV2::TargetGroup" do |r|
          r.property(:name) { "#{environment}-default" }
          r.property(:vpc_id) { :vpc.ref }
          r.property(:port) { 80 }
          r.property(:protocol) { "HTTP" }
        end

        output :ecs_load_balancer,
               description: "ECS Application Load Balancer",
               value: :ecs_load_balancer.ref

        output :ecs_load_balancer_url,
               description: "URL of the ECS ALB",
               value: :ecs_load_balancer.ref("DNSName")

        output :ecs_load_balancer_listener,
               description: "ECS Port 80 listener",
               value: :load_balancer_listener.ref

        output :ecs_load_balancer_hosted_zone_id,
               description: "Canonical Hosted Zone ID of the ALB",
               value: :ecs_load_balancer.ref("CanonicalHostedZoneID")
      end
    end
  end
end
