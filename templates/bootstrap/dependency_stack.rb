description "Dependency Stack"

parameter :environment,
          description: "Environment name",
          type: "String"

parameter :domain_name,
          description: "Domain name",
          type: "String"

condition :has_environment,
          [["", :environment.ref].fnequals].fnnot

condition :has_domain_name,
          [["", :domain_name.ref].fnequals].fnnot

%i(
  artifact_bucket
  cloudformation_bucket
  lambda_bucket
  logging_bucket
).each do |bucket|
  resource bucket,
           deletion_policy: "Retain",
           update_replace_policy: "Retain",
           type: "AWS::S3::Bucket"

  output bucket,
         value: bucket.ref
end

resource :hosted_zone,
         condition: "HasDomainName",
         type: "AWS::Route53::HostedZone" do |r|
  r.property(:hosted_zone_config) do
    {
      "Comment": ["Hosted zone for ", ["HasEnvironment", [:environment.ref, "."].fnjoin, ""].fnif, :domain_name.ref].fnjoin
    }
  end
  r.property(:name) { [["HasEnvironment", [:environment.ref, "."].fnjoin, ""].fnif, :domain_name.ref].fnjoin }
end

output :hosted_zone_id,
       condition: "HasDomainName",
       value: :hosted_zone.ref

output :hosted_zone_name,
       condition: "HasDomainName",
       value: [["HasEnvironment", [:environment.ref, "."].fnjoin, ""].fnif, :domain_name.ref].fnjoin
