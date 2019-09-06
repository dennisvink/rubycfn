# Rubycfn RubyCFN is a light-weight CloudFormation DSL
require "active_support/concern"
require "json"
require "neatjson"
require "rubycfn/version"

@depends_on = []
@description = ""
@transform = ""
@outputs = {}
@parameters = {}
@properties = {}
@metadata = {}
@mappings = {}
@conditions = {}
@aws_resources = {}
@imports = []
@resource_name = ""
@variables = {}
@global_variables = {}

# Monkey patching
class Symbol
  def ref(attr = nil)
    unless attr
      return { Ref: to_s.split("_").map(&:capitalize).join }
    end
    attr = attr.class == String ? attr : attr.to_s.split("_").map(&:capitalize).join
    {
      "Fn::GetAtt": [
        to_s.split("_").map(&:capitalize).join, attr
      ]
    }
  end
end

class Hash
  def fnsplit(separator = "")
    {
      "Fn::Split": [
        separator,
        self
      ]
    }
  end
end

class String
  def cfnize
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split("_").map(&:capitalize).join
  end

  def ref(attr = nil)
    unless attr
      return { Ref: self }
    end
    attr = attr.class == String ? attr : attr.to_s.split("_").map(&:capitalize).join
    {
      "Fn::GetAtt": [
        self,
        attr
      ]
    }
  end

  def fnsplit(separator = "")
    {
      "Fn::Split": [
        separator,
        self
      ]
    }
  end

  def fnbase64
    {
      "Fn::Base64": self
    }
  end

  def fngetazs
    {
      "Fn::GetAZs": self
    }
  end

  def fnsub(variable_map = nil)
    unless variable_map
      return { "Fn::Sub": self }
    end
    {
      "Fn::Sub": [
        self,
        variable_map
      ]
    }
  end

  def fnimportvalue
    {
      "Fn::Import": self
    }
  end
  alias_method :fnimport, :fnimportvalue
end

class Array
  def fncidr
    {
      "Fn::Cidr": self
    }
  end
  alias_method :cidr, :fncidr

  def fnequals
    {
      "Fn::Equals": self
    }
  end

  def fnand
    {
      "Fn::And": self
    }
  end

  def fnif
    {
      "Fn::If": self
    }
  end

  def fnnot
    {
      "Fn::Not": self
    }
  end

  def fnor
    {
      "Fn::Or": self
    }
  end

  def fnfindinmap(name = nil)
    unshift(name.cfnize) if name
    {
      "Fn::FindInMap": self
    }
  end
  alias_method :find_in_map, :fnfindinmap
  alias_method :findinmap, :fnfindinmap

  def fnjoin(separator = "")
    {
      "Fn::Join": [
        separator,
        self
      ]
    }
  end

  def fnselect(index = 0)
    {
      "Fn::Select": [
        index,
        self
      ]
    }
  end
end

class ::Hash
  def deep_merge(second)
    merger = proc { |_key, v1, v2| Hash == v1 && Hash == v2 ? v1.merge(v2, &merger) : Array == v1 && Array == v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
    merge(second.to_h, &merger)
  end

  def recursive_compact
    delete_if do |k, v|
      next if v == false || k =~ /Fn\:/
      (v.respond_to?(:empty?) ? v.empty? : !v) || v.instance_of?(Hash) && v.recursive_compact.empty?
    end
  end

  def compact
    delete_if { |_k, v| v.nil? }
  end

  def fnselect(index = 0)
    {
      "Fn::Select": [
        index,
        self
      ]
    }
  end
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

    def self.meta(name, _index = 0, &block)
      name = name.class == Symbol ? TOPLEVEL_BINDING.eval("'#{name}'.cfnize") : TOPLEVEL_BINDING.eval("'#{name}'")
      res = { "#{name}": yield(block) }
      TOPLEVEL_BINDING.eval("@metadata = @metadata.deep_merge(#{res})")
    end

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

          res = {
            "#{name.to_s}#{i.zero? ? "" : resource_postpend}": {
              DependsOn: TOPLEVEL_BINDING.eval("@depends_on"),
              Metadata: TOPLEVEL_BINDING.eval("@metadata"),
              Properties: TOPLEVEL_BINDING.eval("@properties"),
              Type: arguments[:type],
              Condition: arguments[:condition]
            }
          }
          TOPLEVEL_BINDING.eval("@aws_resources = @aws_resources.deep_merge(#{res})")
        end
        TOPLEVEL_BINDING.eval("@depends_on = []")
        TOPLEVEL_BINDING.eval("@properties = {}")
        TOPLEVEL_BINDING.eval("@metadata = {}")
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
        TOPLEVEL_BINDING.eval("@variables = @aws_resources = @outputs = @metadata = @properties = @mappings = @parameters = {}")
        TOPLEVEL_BINDING.eval("@depends_on = []")
        TOPLEVEL_BINDING.eval("@description = ''")
        TOPLEVEL_BINDING.eval("@transform = ''")
        JSON.pretty_generate(skeleton.recursive_compact)
      end
    end
  end
end
