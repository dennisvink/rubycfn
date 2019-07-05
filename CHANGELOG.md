# Change Log
All notable changes to Rubycfn will be documented in this file.
This project uses [Semantic Versioning](http://semver.org/).

## 0.3.5 (Next Release)

## 0.3.4

  * Added r.meta method to create resource Metadata -- [@dennisvink][@dennisvink]

## 0.3.3

  * Added new skeleton for projects -- [@dennisvink][@dennisvink]

## 0.3.2
  * Added AWS::Serverless::Transform capability -- [@dennisvink][@dennisvink]

## 0.3.1
  * Fixed bug in VPC template generation -- [@dennisvink][@dennisvink]

## 0.3.0
  * Removed non-AWS code. For non-AWS resources pin to 0.2.1 -- [@dennisvink][@dennisvink]
 
## 0.2.1
  * Fixed bug in VPC compound resource. Resource names are now camel cased -- [@dennisvink][@dennisvink]
  * Updated README.md -- [@dennisvink][@dennisvink]

## 0.2.0
  * Added support for GCP templates -- [@dennisvink][@dennisvink]
  * No camel casing property and resource names if type is String instead of Symbol -- [@dennisvink][@dennisvink]

## 0.1.11
  * Added small script to convert a CloudFormation template to Rubycfn code -- [@dennisvink][@dennisvink]

## 0.1.10
  * Added conditions section support, condition in resources, and added several missing intrinsic functions. -- [@dennisvink][@dennisvink]

## 0.1.9
  * Merged feature/cicd into release :') -- [@dennisvink][@dennisvink]

## 0.1.8
  * `Export` in outputs now takes both strings and hashes -- [@dennisvink][@dennisvink]

## 0.1.7
  * Added specs to default project -- [@dennisvink][@dennisvink]
  * Added CI/CD pipeline to default project -- [@dennisvink][@dennisvink]
  * Removed missing method from default project -- [@dennisvink][@dennisvink]

## 0.1.6
  * Fixed bug where variables that were passed a `false` (boolean) value invoked super -- [@dennisvink][@dennisvink]
  * Skip compacting of `false` boolean values in json output -- [@dennisvink][@dennisvink]
  * Fixed layout default rendered project concern
 
## 0.1.5
  * Fixed bug where properties were not reset when amount was greater than 1 -- [@dennisvink][@dennisvink]

## 0.1.4 
  * Made resource names overridable from within resource block with `_id` resource method. -- [@dennisvink][@dennisvink]

## 0.1.3
  * Fixed incorrect property name in generated default project -- [@dennisvink][@dennisvink]

## 0.1.2
  * Added VPC to default project -- [@dennisvink][@dennisvink]
  * Pass original resource name to compound resources -- [@dennisvink][@dennisvink]
  * Prefix environment name to outputted json stack -- [@dennisvink][@dennisvink]
  * Added support for mappings and Fn::FindInMap -- [@dennisvink][@dennisvink]

## 0.1.1
  * Added Rubycfn CLI to generate new projects -- [@dennisvink][@dennisvink]

[@dennisvink]: https://github.com/dennisvink

