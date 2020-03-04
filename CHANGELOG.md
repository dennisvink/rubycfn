# Change Log
All notable changes to Rubycfn will be documented in this file.
This project uses [Semantic Versioning](http://semver.org/).

## 0.5.0 (Next Release)

  * Restructuring project -- [@dennisvink][@dennisvink]

## 0.4.10

  * Added support for conditions in outputs -- [@dennisvink][@dennisvink]

## 0.4.9

  * Added fnbase64 to Hash monkeypatch -- [@dennisvink][@dennisvink]
  * Updated README.md

## 0.4.8

  * Allow for AWS::CDK::Metadata Resources -- [@dennisvink][@dennisvink]
  * Added fnsub to Hash in monkeypatch.rb -- [@dennisvink][@dennisvink]

## 0.4.7

  * Added `fnsub` to Hash monkeypatch -- [@dennisvink][@dennisvink]

## 0.4.6

  * Added `template` attribute to variables -- [@dennisvink][@dennisvink]
  * Added `rubycfn stack` command to add new stack quickly -- [@dennisvink][@dennisvink]
  * Added `get_output` method -- [@dennisvink][@dennisvink]

## 0.4.5

  * Added `empty_string` method to allow for empty string as property value -- [@dennisvink][@dennisvink]

## 0.4.4

  * Added autocorrection to property names so that developers won't have to think about camel casing -- [@dennisvink][@dennisvink]

## 0.4.3

  * Fixed bug with property raise error causing confusing spec errors -- [@dennisvink][@dennisvink]

## 0.4.2

  * Added CloudFormationResourceSpecification.json validation -- [@dennisvink][@dennisvink]
 
## 0.4.1

  * Fixed bug with DependsOn not being rendered correctly on multiple instances of resource -- [@dennisvink][@dennisvink]
  * Added specs for Ref and Fn::GetAtt transformations with strings and symbols -- [@dennisvink][@dennisvink]

## 0.4.0

  * Added resource elements `update_policy`, `update_replace_policy`, `metadata`, `depends_on`, `deletion_policy` and `creation_policy`.
  * This release breaks the `r.meta` property. -- [@dennisvink][@dennisvink]

## 0.3.9

  * Add support for UpdatePolicy element in resource -- [@leonrodenburg][@leonrodenburg]

## 0.3.8

  * Added Fn::Transform intrinsic function `.fntransform` -- [@dennisvink][@dennisvink]
  * Refactored some code -- [@dennisvink][@dennisvink]

## 0.3.7

  * Allow symbols to be passed to Ref as argument for Fn::GetAtt -- [@dennisvink][@dennisvink]
  * Added .gitignore to default project template -- [@dennisvink][@dennisvink]

## 0.3.6

  * Added STDIN pipe to rubycfn cli and file name argument support -- [@dennisvink][@dennisvink]

## 0.3.5

  * Added spec helper as require_relative to specss -- [@dennisvink][@dennisvink]
  * Allow .fnsplit to be chained to .fnjoin -- [@dennisvink][@dennisvink]
  * Allow .ref to be chained to Hash -- [@dennisvink][@dennisvink]

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
[@leonrodenburg]: https://github.com/leonrodenburg
