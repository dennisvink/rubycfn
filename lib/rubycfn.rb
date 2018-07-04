# Rubycfn RubyCFN is a light-weight CloudFormation DSL
require "neatjson"
require "json"
require "rubycfn/version"
require "compound/resources"
require 'active_support/concern'

@depends_on = [] 
@description = ""
@outputs = {}
@parameters = {}
@properties = {}
@mappings = {}
@resources = {}
@variables = {}
@global_variables = {}

# Monkey patching
class String
  def cfnize
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split('_').map{|e| e.capitalize}.join
  end

  def ref(attr = nil)
    unless attr
      return { Ref: self }
    end
    return { "Fn::GetAtt": [ self, attr ] }
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
    return { "Fn::Base64": self }
  end

  def fngetazs
    return { "Fn::GetAZs": self }
  end

  def fnsub(variable_map = nil)
    unless variable_map
      return { "Fn::Sub": self }
    end
    return { "Fn::Sub": [ self, variable_map ] }
  end

  def fnimportvalue
    return { "Fn::Import": self }
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
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
    self.merge(second.to_h, &merger)
  end

  def recursive_compact
    delete_if do |k, v|
      (v.respond_to?(:empty?) ? v.empty? : !v) or v.instance_of?(Hash) && v.recursive_compact.empty?
    end
  end

  def compact
    delete_if { |k, v| v.nil? }
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
    def self.method_missing(name, *args)
      super unless TOPLEVEL_BINDING.eval("@variables[:#{name}]") || \
                   TOPLEVEL_BINDING.eval("@global_variables[:#{name}]")
      if TOPLEVEL_BINDING.eval("@variables[:#{name}]")
        TOPLEVEL_BINDING.eval("@variables[:#{name}]")
      else
        TOPLEVEL_BINDING.eval("@global_variables[:#{name}]")
      end
    end

    def self.description(description = "")
      unless description.nil?
        TOPLEVEL_BINDING.eval("@description = '#{description}'")
      end
    end

    def self.mapping(name, arguments = {})
      raise "`name` is required for mapping." unless arguments[:name]
      unless arguments[:data]
        %w(key value).each do |k|
          raise "`#{k}` is required for mapping, unless a `data` hash is passed." unless arguments[k.to_sym]
        end
      end

      name = name.to_s.cfnize
      kv_pairs = arguments[:data] ? arguments[:data] : { "#{arguments[:key]}": "#{arguments[:value]}" }
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
        arguments[:value] = self.send(arguments[:filter], arguments[:value])
      end

      res = {
        "#{name}": arguments[:value]
      }
      if arguments[:global] == false
        TOPLEVEL_BINDING.eval("@variables = @variables.deep_merge(#{res})")
      else
        TOPLEVEL_BINDING.eval("@global_variables = @global_variables.deep_merge(#{res})")
        TOPLEVEL_BINDING.eval("@variables = @variables.deep_merge(#{res})")
      end
    end

    def self.depends_on(resources)
      case resources
        when String
          resources = [resources.cfnize]
        when Array
          resources = resources.map { |r| r.cfnize }
      end
      TOPLEVEL_BINDING.eval("@depends_on = #{resources}")
    end

    def self.set(name, index = 0, &block)
      res = {
        "#{name}": yield
      }
      TOPLEVEL_BINDING.eval("@variables = @variables.deep_merge(#{res})")
    end

    def self.property(name, index = 0, &block)
      name = TOPLEVEL_BINDING.eval("'#{name}'.cfnize")
      res = { "#{name}": yield(block) }
      TOPLEVEL_BINDING.eval("@properties = @properties.deep_merge(#{res})")
    end

    def self.resource(name, arguments, &block)
      arguments[:amount] ||= 1
      name = name.to_s.cfnize
      arguments[:amount].times do |i|
        resource_suffix = i == 0 ? "" : "#{i+1}"
        if arguments[:type].class == Module
          send("include", arguments[:type][name, resource_suffix, &block])
        else
          yield self, i if block_given?
          res = {
            "#{name.to_s}#{i == 0 ? "" : i+1}": {
              DependsOn: TOPLEVEL_BINDING.eval("@depends_on"),
              Properties: TOPLEVEL_BINDING.eval("@properties"),
              Type: arguments[:type]
            }
          }
          TOPLEVEL_BINDING.eval("@resources = @resources.deep_merge(#{res})")
        end
      end
      TOPLEVEL_BINDING.eval("@depends_on = []")
      TOPLEVEL_BINDING.eval("@properties = {}")
    end

    def self.sort_json(obj)
      JSON.parse(
        JSON.neat_generate(obj, sort: true)
      )
    end

    def self.render_template
      skeleton = { "AWSTemplateFormatVersion": "2010-09-09" }
      skeleton = JSON.parse(skeleton.to_json)
      skeleton.merge!(Description: TOPLEVEL_BINDING.eval("@description"))
      skeleton.merge!(Mappings: sort_json(TOPLEVEL_BINDING.eval("@mappings")))
      skeleton.merge!(Parameters: sort_json(TOPLEVEL_BINDING.eval("@parameters")))
      skeleton.merge!(Resources: sort_json(TOPLEVEL_BINDING.eval("@resources")))
      skeleton.merge!(Outputs: sort_json(TOPLEVEL_BINDING.eval("@outputs")))
      TOPLEVEL_BINDING.eval("@variables = @resources = @outputs = @properties = @mappings = @parameters = {}")
      TOPLEVEL_BINDING.eval("@depends_on = []")
      TOPLEVEL_BINDING.eval("@description = ''")
      JSON.pretty_generate(skeleton.recursive_compact)
    end
  end
end
