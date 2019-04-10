# RubyCfn

[RubyCfn](https://rubycfn.com/) is a light-weight tiny CloudFormation, Deployment Manager and ARM DSL to make expressing
AWS templates as Ruby code a bit more pleasing to the eye.

## Quick start

Install Rubycfn:
`gem install rubycfn`

Starting a new Rubycfn project:
`rubycfn`
```$ rubycfn
__________ ____ __________________.___._________ _____________________
\______   \    |   \______   \__  |   |\_   ___ \\_   _____/\______   \
 |       _/    |   /|    |  _//   |   |/    \  \/ |    __)   |    |  _/
 |    |   \    |  / |    |   \\____   |\     \____|     \    |    |   \
 |____|_  /______/  |______  // ______| \______  /\___  /    |______  /
        \/                 \/ \/               \/     \/            \/ [v0.2.1]
Project name? example
Account ID? 1234567890
Select region EU (Frankfurt)
```

Installing project dependencies:
`bundle`

Updating project dependencies:
`bundle update`

Compiling Rubycfn project:
`rake compile`

Running Rubycfn unit tests:
`rake spec`

Running tests and compiling:
`rake`

Converting CloudFormation JSON template to Rubycfn:
`./cfn2rubycfn /path/to/cloudformation_template.json`

## Philosophy

Standardisation is key to keep your engineering team agile. Time spent on projects that deviate from a standard implementation is time taken away from delivering value. Custom implementations are detrimental to a team’s velocity and scalability. It hinders knowledge sharing as a select few have knowledge about the specifics of such a custom implementation, and because the wheel is reinvented many times over proper testing is tedious at best. We’ve automated best practices and ensured that new projects automatically incorporate our principles. Our tooling has been built with cloud engineer happiness in mind.

## Overview of Rubycfn

RubyCfn is an abstraction layer around several Cloud templates such as CloudFormation (AWS). Rubycfn projects are set up for easy grouping of resources that have a mutual cohesion, and structured in such a way to make it easy for developers to quickly find what they need. Rubycfn is a so-called ‘DSL’ on top of these template formats and presents templates as code that is friendly to the eye and easy to read and understand. In addition of being an alternate representation of a template, Rubycfn allows you to combine template generation with programming logic making it far more versatile than what AWS offers in their templates. Last but not least Rubycfn enforces code quality by testing the generated templates against unit tests, checking if the expected resources and their configuration matches with what was actually generated, and by LINTing the templates and the underlying code that generates the templates.

Out of the box Rubycfn comes with a CI/CD pipeline. It’s a serverless pipeline running on Amazon Web Services (AWS), which you can fully configure using the complimentary `buildspec.yml`.  The CI/CD pipeline is linked to a Github repository, and a change in this repository triggers the CI/CD pipeline to execute the steps you’ve defined in the buildspec.yml.

Typically a commit to your application GIT repository triggers the build process and the following things happen:
- Application code is checked out
- Infrastructure as code (Rubycfn project) is checked out
- Rubycfn project is ‘built’, kicking off unit tests against the underlying code, and against the resulting build artifact (template(s))
- Application (unit) tests are ran
- The build artifact is stored (versioned), so you can use it as input for your delivery pipeline
- The artifact may or may not include the application code. A part of the build process could - for example - also be that the application is dockerized and pushed to a docker registry.
- The resulting artifact is the complete recipe to deploy the application and associated resources to AWS

## Example code

You can find stack examples at [https://github.com/dennisvink/rubycfn-example](https://github.com/dennisvink/rubycfn-example/)

## Installing Gems

Type `bundle install` to install all dependencies that are listed in the Gemfile.

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

I've deliberately added amount: 1 to the hosted_zone_ses resources, which is not
necessary as this defaults to 1 if you omit it. If you want multiple resources of
the same type just increase the amount. The resource names will be enumerated,
e.g. Resource, Resource2, Resource3, etc.

With |r, index| you will be have to access the index number of the generated
resource in the `index` variable.

For example:

```ruby
      resource :my_s3_bucket,
               amount: 10,
               type: "AWS::S3::Bucket" do |r, index|

        r.property(:name) { "MyAwesomeBucket#{index+1}" }
      end
```

## Implemented AWS functions

You can Ref by postpending the .ref method to any string. E.g. "string".ref
If you supply an argument to .ref it'll be rendered as Fn::GetAtt. Last but
not least, calling Fn::Join is achieved by postpending .fnjoin to an array.
You can provide it with an argument for the separator. By default its "".

You can use the following methods in the same fashion:

fnsplit, fnbase64, fnjoin and fnselect 

## Outputting to YAML

`brew install cfnflip`

or...

Paste the CloudFormation output in [cfnflip.com](https://cfnflip.com/) to
convert it to YAML format ;)

## The anatomy of a Rubycfn project

When you start a new Rubycfn project it comes structured out of the box. We standardise this structure so that it’s uniform from project to project. A colleague Cloud Engineer needs to be able to take over or troubleshoot a project immediately without having to learn the inner working of the project first. This allows us to remain agile. In addition, by not having to rely on pre-existing knowledge about a project (and thus having knowledge of a project with just a few select people), we promote synergy.

You start a new project by typing `rubycfn` at the prompt. This will ask you a couple of questions about the project - such as the project’s name. The entire project is then generated for you. It then looks like this:

-rw-r--r--   1 binx  staff   166 Oct 17 16:06 .env
-rw-r--r--   1 binx  staff    81 Oct 17 16:06 .env.test
-rw-r--r--   1 binx  staff   246 Oct 17 16:06 Gemfile
-rw-r--r--   1 binx  staff   346 Oct 17 16:06 Rakefile
drwxr-xr-x   2 binx  staff    64 Oct 17 16:06 build
-rwxrwxrwx   1 binx  staff  3223 Oct 17 16:06 cfn2rubycfn
drwxr-xr-x   3 binx  staff    96 Oct 17 16:06 config
-rw-r--r--   1 binx  staff    15 Oct 17 16:06 format.vim
drwxr-xr-x   6 binx  staff   192 Oct 17 16:06 lib
drwxr-xr-x   4 binx  staff   128 Oct 17 16:06 spec

First the flat files:

`.env` and `.env.test` are files where you store environment variables that you may want to use in your project code. The difference between the .env and the .env.test file is that the .env file is the “global” environment variable file, whereas the .env.test file is an environment-specific environment variable file, that can override values you’ve specified in your .env file (or add new environment variables, for that matter). You’d typically have a .env.test, .env.acceptance and a .env.production file for things like instance sizing.

Example:
```$ cat .env.test
# ENV vars for test environment
APPLICATION_INSTANCE_CLASS="t2.micro"
```

To make use of - for example - .env.production as source, you can either override the ENVIRONMENT variable in the .env file, setting it to production, or you can invoke rake as: `ENVIRONMENT="production" rake`.

The `Gemfile` is a collection of Ruby dependencies. By running `bundle` you install the dependencies.

The `Rakefile` contain the tasks that are performed when you type the `rake` command. It consists of a `compile` task and a `spec` task. You can invoke the tasks individually by typing `rake compile` or `rake spec`, but by default the `spec` task is ran first, and then the `compile` task. A “spec” is another word for unit test. It’s important to run the unit test first, so that if a test fails no template is generated. If you just run `rake` both tasks are executed sequentially, provided the specs throw no error.

`cfn2rubycfn` is a small helper script that converts AWS CloudFormation scripts to Rubycfn code. This allows you to migrate your existing projects over to Rubycfn quickly. It exports the converted CloudFormation script to `generated.rb`, a ready to use module for your stacks.

Example:
```
$ cat sample.json
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Resources": {
    "ApiGatewayRestApi": {
      "Properties": {
        "Name": "trigger-github-webhook"
      },
      "Type": "AWS::ApiGateway::RestApi"
    }
  }
}

$ ./cfn2rubycfn sample.json
Reformatting code...

$ cat generated.rb
module ConvertedStack
  module Main
    extend ActiveSupport::Concern
    included do
      resource :api_gateway_rest_api,
        type: "AWS::ApiGateway::RestApi" do |r|
        r.property(:name) { "trigger-github-webhook" }
      end
    end
  end
end
```

The `format.vim` file is used by the CloudFormation conversion script to reindent the file after conversion. You can make changes to the file to reflect your preferred style of code indentation.

Onto the subdirectories:

The `build` directory is where all the compiled templates end up.

Example:
```
$ ls -al build/
total 24
drwxr-xr-x   4 binx  staff   128 Oct 17 16:27 .
drwxr-xr-x  16 binx  staff   512 Oct 17 16:27 ..
-rw-r--r--   1 binx  staff  4152 Oct 17 16:27 test-aws-demostack.json
```

The `spec` directory is where your unit tests live. These are not your application unit tests. A Rubycfn project lives in another universe than your application code. These unit tests test your expectations of the generated templates against reality. Such tests typically check for the existence and absence of particular resources, and values of properties. The tests are always executed when you run the `rake` command or the `rake spec` command. By default a project comes with unit tests that amongst other things check for the generation of the CI/CD pipeline and if it’s been configured correctly.

Example:
```
      context "Codebuild Service Role" do
        let(:code_build_service_role) { resources["CodeBuildDemoServiceRole"] }
        subject { code_build_service_role }

        it { should have_key "Properties" }

        context "Code build service role properties" do
          let(:code_build_service_role_properties) { code_build_service_role["Properties"] }
          subject { code_build_service_role_properties }

          it { should have_key "AssumeRolePolicyDocument" }
          it { should have_key "Path" }
          it { should have_key "Policies" }

          context "Code build service role policy document" do
            let(:policy_document) { code_build_service_role_properties["Policies"][0]["PolicyDocument"] }
            subject { policy_document }

            it { should have_key "Statement" }

            context "Code build service role actions" do
              let(:statement) { policy_document["Statement"][0]["Action"] }
              subject { statement }

              it { should eq %w(logs:CreateLogGroup logs:CreateLogStream logs:PutLogEvents) }
            end
          end
        end
      end
```

The `config` directory contains your buildspec.yml, which contain all the instructions for the build pipeline. It’s also possible to source the buildspec.yml from another source, such as the application repository.

And finally, the `lib` directory contains all the relevant project code. The `lib` directory consists of several files and directories. The `lib/main.rb` is the bootstrapper that ties everything together. The `lib/compile.rb` is responsible for compiling the templates and writing them to the build directory.

There are two directories under `lib`, namely `shared_concerns` and `stacks`. Concerns in this context simply mean Modules. Rubycfn relies on the ActiveConcern gem which makes modularisation of code very easy. The `shared_concerns` directory contains modules that can be used by several stacks. By default it has a `global_variables` module containing the following:

```
module Concerns
  module GlobalVariables
    extend ActiveSupport::Concern

    included do
      variable :environment,
               default: "test",
               global: true,
               value: ENV["ENVIRONMENT"]
    end
  end
end
```
This module exposes a variable `environment`, which defaults to `test` if not set. It sources the value from the ENVIRONMENT environment variable. This variable can be used throughout your project at any place you see fit.

The `stacks` directory is a container for all stacks that you want to generate. There is no limitation to the amount of stacks that it supports. By default, it comes with a single stack for your project:

Example `lib/stacks/demo_stack.rb`:
```
module DemoStack
  extend ActiveSupport::Concern
  include Rubycfn

  included do
    include DemoStack::Main
    include DemoStack::CICD
  end
end
```
Our stack file consists of two modules: Main and CICD. When compiling the code, the combined result of the Main and CICD module will be written to the DemoStack json file in the build/ directory. Modularising stacks allows for separation of code by cohesion or any other logic you deem appropriate.

The stacks directory also contains a directory that is named the same, minus the .rb extension: `lib/stacks/demo_stack/`

All the stack modules live inside this directory. The modules that make up the stack are the actual implementation of the resources, parameters and outputs.

An example of such a module:
```
module DemoStack
  module Main
    extend ActiveSupport::Concern
    included do

      resource :api_gateway_rest_api,
        type: "AWS::ApiGateway::RestApi" do |r|
        r.property(:name) { "#{environment}-webhook" }
      end
    end
  end
end
```

## License

MIT License

Copyright (c) 2019 Dennis Vink

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
