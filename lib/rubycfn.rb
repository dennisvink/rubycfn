# Rubycfn RubyCFN is a light-weight CloudFormation DSL
require "neatjson"
require "json"
require "rubycfn/version"
require 'active_support/concern'

@parameters = {}
@properties = {}
@resources = {}
@outputs = {}
@depends_on = [] 

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
end

class Array
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
end

module Rubycfn
  extend ActiveSupport::Concern

  included do
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

    # attr_accessor :properties
    def self.resource(name, arguments, &block)
      arguments[:amount] ||= 1
      name = name.to_s.cfnize
     
      def self.depends_on(resources)
        case resources
          when String
            resources = [resources.cfnize]
          when Array
            resources = resources.map { |r| r.cfnize }
        end
        TOPLEVEL_BINDING.eval("@depends_on = #{resources}")
      end

      def self.property(name, index = 0, &block)
        name = TOPLEVEL_BINDING.eval("'#{name}'.cfnize")
        res = { "#{name}": yield(block) }
        TOPLEVEL_BINDING.eval("@properties = @properties.deep_merge(#{res})")
      end

      arguments[:amount].times do |i|
        yield self, i if block_given?
        res = {
          "#{name.to_s}#{i == 0 ? "" : i+1}": {
            Properties: TOPLEVEL_BINDING.eval("@properties"),
            Type: arguments[:type]
          }
        }
        TOPLEVEL_BINDING.eval("@resources = @resources.deep_merge(#{res})")
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
      skeleton.merge!(Parameters: sort_json(TOPLEVEL_BINDING.eval("@parameters")))
      skeleton.merge!(Resources: sort_json(TOPLEVEL_BINDING.eval("@resources")))
      skeleton.merge!(Outputs: sort_json(TOPLEVEL_BINDING.eval("@outputs")))
      TOPLEVEL_BINDING.eval("@resources = @outputs = @properties = @parameters = {}")
      TOPLEVEL_BINDING.eval("@depends_on = []")
      JSON.pretty_generate(skeleton.recursive_compact)
    end
  end
end
