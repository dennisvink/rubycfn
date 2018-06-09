# RubyCfn

RubyCfn is a light-weight tiny CloudFormation DSL to make expressing
CloudFormation as Ruby code a bit more pleasing to the eye.

## Installation

Type: `gem install rubycfn`

or, create a Gemfile with this content:

```
source "https://rubygems.org"

gem "rubycfn", "~> 0.0.3"

```

## Running specs

Type `rake` to run the tests. It tests if RubyCfn creates a valid
CloudFormation stack.

## Example usage

```ruby
require "rubycfn"

module DnsStack
  extend ActiveSupport::Concern
  include Rubycfn

  included do
    parameter :domain_name,
              default: "example.com",
              description: "Domain name for the HostedZone"

    resource :hosted_zone,
               type: "AWS::Route53::HostedZone" do |r|
      r.property(:hosted_zone_config) do
        {
          Comment: [
            "Hosted Zone for ",
            "DomainName".ref
          ].fnjoin
        }
      end
      r.property(:name) { "DomainName".ref }
    end

    resource :hosted_zone_ses,
             amount: 1,
             type: "AWS::SES::ConfigurationSet" do |r|
      r.depends_on "HostedZone"
      r.property(:name) { ["HostedZone".ref, "_SESConfigurationSet"].fnjoin }
    end

    output :hosted_zone_id,
           value: "HostedZone".ref,
           description: "HostedZoneId",
           export: {
             "Name": ["AWS::StackName".ref, "HostedZoneId"].fnjoin(":")
           }

  end
end

MyDemoStack = include DnsStack
puts MyDemoStack.render_template

```

I've deliberately added amount: 1 to the hosted_zone_ses resource. If you want
multiple resources of the same type just increase the amount. The resource names
will be enumerated, e.g. Resource, Resource2, Resource3, etc.

The above code renders into this CloudFormation template:

```json
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Parameters": {
    "DomainName": {
      "Default": "example.com",
      "Description": "Domain name for the HostedZone",
      "Type": "String"
    }
  },
  "Resources": {
    "HostedZone": {
      "Properties": {
        "HostedZoneConfig": {
          "Comment": {
            "Fn::Join": [
              "",
              [
                "Hosted Zone for ",
                {
                  "Ref": "DomainName"
                }
              ]
            ]
          }
        },
        "Name": {
          "Ref": "DomainName"
        }
      },
      "Type": "AWS::Route53::HostedZone"
    },
    "HostedZoneSes": {
      "DependsOn": [
        "HostedZone"
      ],
      "Properties": {
        "Name": {
          "Fn::Join": [
            "",
            [
              {
                "Ref": "HostedZone"
              },
              "_SESConfigurationSet"
            ]
          ]
        }
      },
      "Type": "AWS::SES::ConfigurationSet"
    }
  },
  "Outputs": {
    "HostedZoneId": {
      "Description": "HostedZoneId",
      "Export": {
        "Name": {
          "Fn::Join": [
            ":",
            [
              {
                "Ref": "AWS::StackName"
              },
              "HostedZoneId"
            ]
          ]
        }
      },
      "Value": {
        "Ref": "HostedZone"
      }
    }
  }
}
```

## Implemented AWS functions

You can Ref by postpending the .ref method to any string. E.g. "string".ref
If you supply an argument to .ref it'll be rendered as Fn::GetAtt. Last but
not least, calling Fn::Join is achieved by postpending .fnjoin to an array.
You can provide it with an argument for the separator. By default its "".

## Outputting to YAML

`brew install cfnflip`

or...

Paste the CloudFormation output in [cfnflip.com](https://cfnflip.com/) to
convert it to YAML format ;)

## License

MIT License

Copyright (c) 2018 Dennis Vink

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
