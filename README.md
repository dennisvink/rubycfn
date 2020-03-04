# RubyCfn

[RubyCfn](https://rubycfn.com/) is a light-weight tiny CloudFormation, and Deployment Manager to make expressing
AWS templates as Ruby code a bit more pleasing to the eye.

You can find the [CloudFormation Compiler](https://rubycfn.com/) at https://rubycfn.com with examples.

## Philosophy

Standardisation is key to keep your engineering team agile. Time spent on projects that deviate from a standard implementation is time taken away from delivering value. Custom implementations are detrimental to a team’s velocity and scalability. It hinders knowledge sharing as a select few have knowledge about the specifics of such a custom implementation, and because the wheel is reinvented many times over proper testing is tedious at best. We’ve automated best practices and ensured that new projects automatically incorporate our principles. Our tooling has been built with cloud engineer happiness in mind.

## Quick start

Install Rubycfn:
```
gem install rubycfn
echo "resource :my_s3_bucket, type: 'AWS::S3::Bucket'" | rubycfn
```

The Rubycfn CLI can be piped to or takes a file name as argument. You can start
by cloning the [Rubycfn Examples Repository](https://github.com/dennisvink/rubycfn-examples/). To generate a CloudFormation template type:

`cat "3. Deploying a Serverless function.rb" | rubycfn`

or

`rubycfn "3. Deploying a Serverless function.rb"`

to generate the CloudFormation template for that example.

Now take this `template.rb` as an example:

```ruby
parameter :bucket_name,
          description: "Bucket name"

resource :foobar,
         type: "AWS::S3::Bucket" do |r|
  r.property(:bucket_name) { :bucket_name.ref }
end
```

You can generate a CloudFormation template from this script in the following ways:
`cat template.rb | rubycfn`

or

`rubycfn template.rb`

Both commands will output the CloudFormation template without the need for you to set up a project.

## Setting up a Rubycfn project

For projects that extend beyond a simple stack or those that require unit
testing you can create a Rubycfn project in the following way:  

`rubycfn`
```$ rubycfn
__________ ____ __________________.___._________ _____________________
\______   \    |   \______   \__  |   |\_   ___ \\_   _____/\______   \
 |       _/    |   /|    |  _//   |   |/    \  \/ |    __)   |    |  _/
 |    |   \    |  / |    |   \\____   |\     \____|     \    |    |   \
 |____|_  /______/  |______  // ______| \______  /\___  /    |______  /
        \/                 \/ \/               \/     \/            \/ [v0.4.10]
Project name? example
Account ID? 1234567890
Select region EU (Frankfurt)
```

## Project commands

Installing project dependencies:
`bundle`

Updating project dependencies:
`bundle update`

Deploying dependency stack to AWS:
`rake init`

Compiling Rubycfn project:
`rake compile`

Running Rubycfn unit tests:
`rake spec`

Running tests and compiling:
`rake`

Uploading built stacks to s3:
`rake upload`

Deploying stack to AWS:
`rake apply`

## Anatomy of a Rubycfn project

A new Rubycfn project has the following structure:

```
drwxr-xr-x   3 dennis  staff     96 Mar  4 02:43 bootstrap
drwxr-xr-x   7 dennis  staff    224 Mar  4 02:43 lib
drwxr-xr-x   4 dennis  staff    128 Mar  4 02:43 spec
-rw-r--r--   1 dennis  staff     49 Mar  4 02:43 .env
-rw-r--r--   1 dennis  staff     31 Mar  4 02:43 .env.acceptance
-rw-r--r--   1 dennis  staff    279 Mar  4 02:43 .env.dependencies.rspec
-rw-r--r--   1 dennis  staff     32 Mar  4 02:43 .env.development
-rw-r--r--   1 dennis  staff     31 Mar  4 02:43 .env.production
-rw-r--r--   1 dennis  staff     33 Mar  4 02:43 .env.rspec
-rw-r--r--   1 dennis  staff     25 Mar  4 02:43 .env.test
-rw-r--r--   1 dennis  staff   1110 Mar  4 02:43 .gitignore
-rw-r--r--   1 dennis  staff   1524 Mar  4 02:43 .rubocop.yml
-rw-r--r--   1 dennis  staff    477 Mar  4 02:43 Gemfile
-rw-r--r--   1 dennis  staff  31603 Mar  4 02:43 Gemfile.lock
-rw-r--r--   1 dennis  staff    292 Mar  4 02:43 README.md
-rw-r--r--   1 dennis  staff   1267 Mar  4 02:43 Rakefile
-rw-r--r--   1 dennis  staff   1337 Mar  4 02:43 config.yaml
```

Lets first discuss the files in the root folder.

```
.env            Global environment variables, available in every environment
.env.production Environment variables available in production environment
.env.test       Environment variables available in test environment
.env.rspec      Environment variables available to unit tests
.rubocop.yml    Ruby LINTer configuration to enforce good code style
Gemfile         Ruby gem dependencies
Gemfile.lock    Resolved gem dependencies
Rakefile        Contains all Rubycfn rake tasks
```

#### .env

The `.env` file contains environment variables that are available, regardless of
the environment you're building for. For example:

```
AWS_REGION="eu-west-1"
ENVIRONMENT="development"
```

#### .env.production and .env.test

The `.env.production` and `.env.x` files contain environment variables that
are specific to production or test respectively. For example `.env.test` can
contain something like this:

```
# ENV vars for test environment
CLOUD_TRAIL_MONITOR_SNS_RECIPIENTS="changeme@example.com,changemetoo@example.com"
ROOT_MONITOR_SNS_RECIPIENTS="changeme@example.com,changemetoo@example.com"
```

You can reuse these environment variables in your project code.

#### .env.rspec

The `.env.rspec` is used when running unit tests. It contains mock variables
so that you can test the resulting CloudFormation templates properly.

#### The missing .env.private file

There is one file that is not generated by default but does need mentioning:
the `.env.private` file. This is a special file that allows you to override
environment variables. An environment variable set in .env.private always takes
precedence over environment variables set in other .env files.

#### .rubocop.yml

The `.rubocop.yml` file contains configuration for the code linter. When running
`rubocop` from the root folder of your project it will error on code style
violations.

### Rubycfn project directories

As shown before, a Rubycfn project contains four directories:

```
drwxr-xr-x   3 dennis  staff     96 Mar  4 02:43 bootstrap
drwxr-xr-x   7 dennis  staff    224 Mar  4 02:43 lib
drwxr-xr-x   4 dennis  staff    128 Mar  4 02:43 spec
```

#### build

The build directory is where your resulting CloudFormation templates will be
stored.

#### lib

The 'lib' directory contains all your stacks, modules and project libraries.
This directory is the most important, as this is the directory where you work
in. I will go into more detail on the `lib` directory in the next chapter.

#### spec

The `spec` directory contains all unit tests. They are executed with the
`rake spec` command.

## The lib directory

As mentioned the `lib` directory is the most important directory. When you
create a Rubycfn project it will contain the following by default:

```
total 8
drwxr-xr-x   7 dennis  staff  224 Jul 15 20:43 .
drwxr-xr-x  16 dennis  staff  512 Jul 15 21:08 ..
drwxr-xr-x   9 dennis  staff  288 Jul 15 20:43 aws_helper
drwxr-xr-x   6 dennis  staff  192 Jul 15 20:43 core
-rw-r--r--   1 dennis  staff  734 Jul 15 20:43 main.rb
drwxr-xr-x   5 dennis  staff  160 Jul 15 20:43 shared_concerns
drwxr-xr-x   8 dennis  staff  256 Jul 15 20:43 stacks
```

The `aws_helper` and `core` directories and the `main.rb` file contains helper
function and a lot of glue to make Rubycfn code compile and deploy. You should
never need to touch those files. In this section I'll focus on the
`shared_concerns` directory and the `stacks` directory.

To understand the purpose of the `shared_concerns` directory it's important to
understand that a stack consists of a parent stack file and modules. Lets say
you have a VPC stack: It will consist of a `vpc_stack.rb` file that includes
modules from the `vpc_stack/` directory. This modular approach keeps your
projects nice and tidy. By default, the shared_concerns directory contains a
global variables module, a shared methods module and a helper methods module.

The `shared_concerns/` directory also contain modules. The difference is that
these modules can be used in more than one stack. If you have resources or code
that you want to reuse cross stacks, create a shared concern.

The `stacks` folder, by default, contains the following:

```
drwxr-xr-x  4 dennis  staff  128 Mar  4 02:43 acm_stack
drwxr-xr-x  6 dennis  staff  192 Mar  4 02:43 ecs_stack
drwxr-xr-x  4 dennis  staff  128 Mar  4 02:43 parent_stack
drwxr-xr-x  4 dennis  staff  128 Mar  4 02:43 vpc_stack
```

The default project creates four CloudFormation templates: a VPC stack, an
ECS stack, an ACM stack and a parent stack. The parent stack is a CloudFormation
stack that contains all other stacks. When you deploy a Rubycfn project these other
stacks show up as `nested stacks`. The parent stack acts not only as a container for
all other stacks, but is also responsible for passing outputs from stacks as
parameters to another. For example: The VPC Id that is created in the VPC stack
can easily be passed to the ECS stack as a parameter. This nested stack approach
has an additional benefit: A change of output in stack X can trigger an update
in stack Y.

The lib/stacks/vpc_stack/ directory contains a `main.rb` file and a `vpc.rb` file.
Lets have a look at the vpc_stack/main.rb file:

```ruby
module VpcStack
  extend ActiveSupport::Concern
  include Rubycfn
  included do
    include Concerns::GlobalVariables
    include Concerns::SharedMethods
    include VpcStack::InfraVpc

    description generate_stack_description("VpcStack")
  end
end
```

On the first line we define the module name. It is important that the module
name ends with 'Stack' to make the compiler magic work. The code between
`include do` and `end` loads in two of the shared concerns, and includes the
VpcStack::Main module. Finally the description of the stack is set.

The `lib/stacks/vpc_stack/vpc.rb` file contains the implementation of the
VpcStack::InfraVpc module: 

```ruby
require_relative "subnets"

module VpcStack
  module InfraVpc
    extend ActiveSupport::Concern

    included do
      # A lot of VPC code here
    end
  end
end
```

The first line is identical to the parent stack file and defines this module is
part of `VpcStack`. The second line defines the name of the module, in this case
`InfraVpc`. The code beteen `included do` and `end` is the implementation of this
module.

## AWS Intrinsic functions

You can Ref by postpending the .ref method to any string or hash, e.g. :foobar.ref
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

## Serverless Transforms

To allow for SAM transformation use the 'transform' method inside your template.
The transform method takes an optional argument, and defaults to "AWS::Serverless-2016-10-31"

## Resource attributes

When creating a resource there are a couple of arguments that can be passed
along with it. In its most simple form a resource looks like this:

```ruby
resource :my_resource,
         type: "AWS::Some::Resource"
```

The following arguments are supported:

* condition
* creation_policy
* deletion_policy
* depends_on
* metadata
* type
* update_policy
* update_replace_policy

To make a resource depend on another resource you can use the `depends_on`
argument as follows:

```ruby
resource :my_resource,
         depends_on: :some_other_resource,
         type: "AWS::Some::Resource"
```

or... if you want to make it dependant on multiple resources:

```ruby
resource :my_resource,
         depends_on: %i(some_other_resource yet_another_resource),
         type: "AWS::Some::Resource"
```

If you want to dynamically generate DependsOn, you can do that in this way:

```ruby
resource :my_resource,
         amount: 2,
         type: "AWS::Some::Resource" do |r, index|
  r.depends_on "SomeResource#{index}"
end
```

The `depends_on` attribute and `r.depends_on` method can be used together.
The `r.depends_on` specified resources get appended to the `depends_on`
specified resources.

## Manipulating the resource name

Common practice is to use a symbol as argument to the `resource` method. The
passed symbol is camel cased in the final CloudFormation template generation.
It is imaginable that you have a use case where you need to control the resource
name. There are two ways to achieve this.

The first method is to pass a string as resource name, rather than a symbol.
When you pass a string it will be taken as the literal resource name and not be
camel cased. E.g.:

```ruby
resource "myAmazingResource",
         type: "AWS::Some::Resource"
```

The second method is to use the resource method `_id`:

```ruby
resource :irrelevant_resource_name,
         amount: 3,
         type: "AWS::Some::Resource" do |r, index|
  r._id "ResourceNameOverride#{index+1}"
end
```

## Resource validation

Rubycfn is shipped with a `CloudFormationResourceSpecification.json` file. It
is used to validate whether used properties are valid and if any mandatory
properties were omitted. The CloudFormation compiler will throw an error if
a mandatory property is missing or if an unknown property is specified. Note
that the CloudFormationResourceSpecification.json is not actively maintained
by me. It is maintained by AWS at:

https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-resource-specification.html

You can also place the `CloudFormationResourceSpecification.json` file in the
root of your project. It will override the one supplied by Rubycfn.

## Authors

Dennis Vink

Contributors:
* Leon Rodenburg

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
