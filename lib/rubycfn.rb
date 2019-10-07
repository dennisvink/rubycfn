# Rubycfn RubyCFN is a light-weight CloudFormation DSL
require "active_support/concern"
require "json"
require "neatjson"
require "rubycfn/version"
require_relative "monkeypatch"

@description = ""
@transform = ""
@outputs = {}
@parameters = {}
@properties = {}
@mappings = {}
@conditions = {}
@aws_resources = {}
@imports = []
@resource_name = ""
@variables = {}
@global_variables = {}

@resource_specification = JSON.parse(File.open(File.join(File.dirname(__FILE__), "/../CloudFormationResourceSpecification.json")).read)
if File.file?("CloudFormationResourceSpecification.json")
  @resource_specification = JSON.parse(File.open("CloudFormationResourceSpecification.json").read)
end

module Rubycfn
  extend ActiveSupport::Concern

  included do
    # rubocop:disable Style/UnneededCondition
    def self.method_missing(name, *args)
      super unless TOPLEVEL_BINDING.eval("@variables[:#{name}]") || \
                   TOPLEVEL_BINDING.eval("@variables[:#{name}] === false") ||
                   TOPLEVEL_BINDING.eval("@global_variables[:#{name}]") ||
                   TOPLEVEL_BINDING.eval("@global_variables[:#{name}] === false")
      if TOPLEVEL_BINDING.eval("@variables[:#{name}]")
        TOPLEVEL_BINDING.eval("@variables[:#{name}]")
      else
        TOPLEVEL_BINDING.eval("@global_variables[:#{name}]")
      end
    end
    # rubocop:enable Style/UnneededCondition

    def self.transform(transform = "AWS::Serverless-2016-10-31")
      return if transform.nil?
      TOPLEVEL_BINDING.eval("@transform = '#{transform}'")
    end

    def self.description(description = "")
      return if description.nil?
      TOPLEVEL_BINDING.eval("@description = '#{description}'")
    end

    def self.condition(name, arguments)
      name = name.to_s.cfnize
      res = {
        "#{name}": arguments
      }
      TOPLEVEL_BINDING.eval("@conditions = @conditions.deep_merge(#{res})")
    end

    def self.mapping(name, arguments = {})
      raise "`name` is required for mapping." unless arguments[:name]
      unless arguments[:data]
        %w(key value).each do |k|
          raise "`#{k}` is required for mapping, unless a `data` hash is passed." unless arguments[k.to_sym]
        end
      end

      name = name.to_s.cfnize
      # rubocop:disable Style/UnneededCondition
      kv_pairs = arguments[:data] ? arguments[:data] : { "#{arguments[:key]}": (arguments[:value]).to_s }
      # rubocop:enable Style/UnneededCondition
      res = {
        "#{name}": {
          "#{arguments[:name]}": kv_pairs
        }
      }
      TOPLEVEL_BINDING.eval("@mappings = @mappings.deep_merge(#{res})")
    end

    def self.empty_string
      "<emptyString>"
    end

    def self.parameter(name, arguments)
      name = name.to_s.cfnize
      arguments[:type] ||= "String"

      param = {
        "Type": arguments[:type],
        "Default": arguments[:default],
        "AllowedValues": arguments[:allowed_values],
        "Description": arguments[:description]
      }.compact
      res = {
        "#{name}": param
      }

      TOPLEVEL_BINDING.eval("@parameters = @parameters.deep_merge(#{res})")
    end

    def self.output(name, arguments)
      name = name.to_s.cfnize
      if arguments[:export]
        unless arguments[:export].respond_to?("each")
          arguments[:export] = { "Name": arguments[:export] }
        end
      end
      param = {
        "Description": arguments[:description],
        "Value": arguments[:value],
        "Export": arguments[:export]
      }.compact
      res = {
        "#{name}": param
      }

      TOPLEVEL_BINDING.eval("@outputs = @outputs.deep_merge(#{res})")
    end

    def self.variable(name, arguments = {})
      arguments[:default] ||= ""
      arguments[:value] ||= ""
      arguments[:required] ||= false
      arguments[:global] ||= false
      arguments[:filter] ||= nil

      if arguments[:value].empty?
        arguments[:value] = arguments[:default]
        if arguments[:required]
          if arguments[:value].empty?
            raise "Property `#{name}` is required."
          end
        end
      end

      if arguments[:filter]
        arguments[:value] = send(arguments[:filter], arguments[:value])
      end

      res = {
        "#{name}": arguments[:value]
      }
      TOPLEVEL_BINDING.eval("@global_variables = @global_variables.deep_merge(#{res})") unless arguments[:global] == false
      TOPLEVEL_BINDING.eval("@variables = @variables.deep_merge(#{res})")
    end

    def self.depends_on(resources)
      case resources
      when String
        resources = [resources.cfnize]
      when Array
        resources = resources.map(&:cfnize)
      end
      TOPLEVEL_BINDING.eval("@depends_on = #{resources}")
    end

    def self._id(name)
      TOPLEVEL_BINDING.eval("@resource_name = '#{name}'")
    end

    # rubocop:disable Lint/UnusedMethodArgument
    def self.set(name, _index = 0, &block)
      res = {
        "#{name}": yield
      }
      TOPLEVEL_BINDING.eval("@variables = @variables.deep_merge(#{res})")
    end
    # rubocop:enable Lint/UnusedMethodArgument

    def self.property(name, _index = 0, &block)
      name = name.class == Symbol ? TOPLEVEL_BINDING.eval("'#{name}'.cfnize") : TOPLEVEL_BINDING.eval("'#{name}'")
      res = { "#{name}": yield(block) }
      TOPLEVEL_BINDING.eval("@properties = @properties.deep_merge(#{res})")
    end

    def self.resource(name, arguments, &block)
      arguments[:amount] ||= 1
      origname = name.to_s
      # Allow for non-camelcased resource names
      name = name.class == Symbol ? name.to_s.cfnize : name = name.to_s
      arguments[:type] =~ /^([A-Za-z0-9]*)\:\:/
      arguments[:cloud] ||= $1
      resource_specification = TOPLEVEL_BINDING.eval("@resource_specification")

      raise "#{arguments[:type]} is not a valid resource type" unless resource_specification["ResourceTypes"][arguments[:type].to_s] || arguments[:type] =~ /Rspec\:\:/ || arguments[:type] =~ /^Custom\:\:/ || arguments[:type] =~ /AWS\:\:Serverless\:\:/

      # Custom resource types are AWS resources
      if arguments[:cloud] == "Custom" || arguments[:cloud] == "Rspec"
        arguments[:cloud] = "AWS"
      end
      arguments[:amount].times do |i|
        resource_suffix = i.zero? ? "" : (i + 1).to_s
        if arguments[:type].class == Module
          send("include", arguments[:type][origname, resource_suffix, &block])
        else
          yield self, i if block_given?

          resource_postpend = TOPLEVEL_BINDING.eval("@resource_name").empty? ? i + 1 : ""
          unless TOPLEVEL_BINDING.eval("@resource_name").empty?
            name = TOPLEVEL_BINDING.eval("@resource_name")
            TOPLEVEL_BINDING.eval("@resource_name = ''")
          end

          # Transform depends_on based on input class
          unless arguments[:depends_on].nil? && TOPLEVEL_BINDING.eval("@depends_on").nil?

            # Initialize arguments[:depends_on] if it is nil
            arguments[:depends_on] = arguments[:depends_on].nil? && [] || arguments[:depends_on]

            # If the argument is a string, create an array out of it with a single element
            arguments[:depends_on] = arguments[:depends_on].class == Array && arguments[:depends_on] || [arguments[:depends_on]]

            # Finally, we render the DependsOn array
            arguments[:depends_on].map! { |resource| resource.class == String && resource.to_s || resource.to_s.split("_").map(&:capitalize).join }
          end

          arguments[:depends_on] ||= []
          rendered_depends_on = TOPLEVEL_BINDING.eval("@depends_on").nil? && arguments[:depends_on] || arguments[:depends_on] + TOPLEVEL_BINDING.eval("@depends_on")
          rendered_properties = TOPLEVEL_BINDING.eval("@properties")
          autocorrected_properties = {}
          if resource_specification["ResourceTypes"][arguments[:type].to_s]
            resource_specification = TOPLEVEL_BINDING.eval("@resource_specification")
            known_properties = resource_specification["ResourceTypes"][arguments[:type].to_s]["Properties"].keys
            mandatory_properties = []
            known_properties.each do |prop|
              mandatory_properties.push(prop) if resource_specification["ResourceTypes"][arguments[:type].to_s]["Properties"][prop]["Required"] == true
            end
            rendered_properties.each do |k, v|
              unless known_properties.include? k.to_s
                # Can we fix it ? Maybe we can
                autocorrected = known_properties.find { |prop| prop.casecmp(k.to_s).zero? }
                if autocorrected.nil?
                  TOPLEVEL_BINDING.eval("@depends_on = []")
                  TOPLEVEL_BINDING.eval("@properties = {}")
                  rendered_properties = {}
                  raise "Property `#{k}` for #{arguments[:type]} is not valid."
                end
                rendered_properties.delete(k)
                autocorrected_properties[autocorrected.to_sym] = v
                mandatory_properties.delete(autocorrected.to_s)
              end
              mandatory_properties.delete(k.to_s)
            end
            rendered_properties = rendered_properties.deep_merge(autocorrected_properties)
            unless mandatory_properties.count.zero?
              TOPLEVEL_BINDING.eval("@depends_on = []")
              TOPLEVEL_BINDING.eval("@properties = {}")
              raise "Property #{mandatory_properties.join(", ")} is mandatory for #{arguments[:type]}"
            end
          end
          res = {
            "#{name.to_s}#{i.zero? ? "" : resource_postpend}": {
              Properties: rendered_properties,
              Type: arguments[:type],
              Condition: arguments[:condition],
              UpdatePolicy: arguments[:update_policy],
              UpdateReplacePolicy: arguments[:update_replace_policy],
              Metadata: arguments[:metadata],
              DependsOn: rendered_depends_on,
              DeletionPolicy: arguments[:deletion_policy],
              CreationPolicy: arguments[:creation_policy]
            }
          }
          TOPLEVEL_BINDING.eval("@aws_resources = @aws_resources.deep_merge(#{res})")
        end
        TOPLEVEL_BINDING.eval("@depends_on = []")
        TOPLEVEL_BINDING.eval("@properties = {}")
      end
    end

    def self.sort_json(obj)
      JSON.parse(
        JSON.neat_generate(obj, sort: true)
      )
    end

    def self.render_template(type = "AWS")
      case type
      when "AWS"
        skeleton = { "AWSTemplateFormatVersion": "2010-09-09" }
        skeleton = JSON.parse(skeleton.to_json)
        skeleton[:Transform] = TOPLEVEL_BINDING.eval("@transform")
        skeleton[:Description] = TOPLEVEL_BINDING.eval("@description")
        skeleton[:Mappings] = sort_json(TOPLEVEL_BINDING.eval("@mappings"))
        skeleton[:Parameters] = sort_json(TOPLEVEL_BINDING.eval("@parameters"))
        skeleton[:Conditions] = sort_json(TOPLEVEL_BINDING.eval("@conditions"))
        skeleton[:Resources] = sort_json(TOPLEVEL_BINDING.eval("@aws_resources"))
        skeleton[:Outputs] = sort_json(TOPLEVEL_BINDING.eval("@outputs"))
        TOPLEVEL_BINDING.eval("@variables = @aws_resources = @outputs = @properties = @mappings = @parameters = {}")
        TOPLEVEL_BINDING.eval("@depends_on = []")
        TOPLEVEL_BINDING.eval("@description = ''")
        TOPLEVEL_BINDING.eval("@transform = ''")
        JSON.pretty_generate(skeleton.recursive_compact).gsub("<emptyString>","")
      end
    end
  end
end
