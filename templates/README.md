# Infrastructure for <%= project_name %>

```
__________ ____ __________________.___._________ _____________________
\______   \    |   \______   \__  |   |\_   ___ \\_   _____/\______   \
 |       _/    |   /|    |  _//   |   |/    \  \/ |    __)   |    |  _/
 |    |   \    |  / |    |   \\____   |\     \____|     \    |    |   \
 |____|_  /______/  |______  // ______| \______  /\___  /    |______  /
        \/                 \/ \/               \/     \/            \/ [<%= version %>]
```

## Prerequisites

- Edit .env.private and configure your AWS credentials, or export your AWS credentials.
- Type `rake init` to create the DependencyStack in your AWS account

## Rake commands

`rake` - Compile the code into CloudFormation templates and run unit tests
`rake init` - Deploy the DependencyStack in the AWS account
`rake compile` - Compile the code into CloudFormation templates
`rake spec` - Run unit tests
`rake upload` - Upload the CloudFormation templates to s3
`rake apply` - Deploy the CloudFormation templates

## Stack configuration

The `config.yaml` file in the root directory of this project contains most of the configuration.  It contains the networking configuration for each environment, subnet configuration, DNS and ECS (Docker) containers that are deployed.

## Adding your own resources

The lib/stacks/ directory contains all nested stacks for this project. Every nested stack has a
directory under lib/stacks/. You can add resources to any of these stacks, or create a new stack altogether. See [https://github.com/dennisvink/rubycfn/blob/master/README.md](https://github.com/dennisvink/rubycfn/blob/master/README.md) for documentation.
