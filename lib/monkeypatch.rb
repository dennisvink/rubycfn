class Symbol
  def cfnize
    return self.to_s if self.to_s !~ /_/ && self.to_s =~ /[A-Z]+.*/
    to_s.split("_").map(&:capitalize).join
  end

  def get_output(attr)
    attr = attr.class == String ? attr : attr.to_s.split("_").map(&:capitalize).join
    {
      "Fn::GetAtt": [
        to_s.split("_").map(&:capitalize).join, "Outputs.#{attr}"
      ]
    }
  end

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

  def fntransform(parameters = nil)
    raise "fntransform parameters must be of type Hash" unless parameters.class == Hash
    {
      "Fn::Transform": {
        "Name": to_s.split("_").map(&:capitalize).join,
        "Parameters": parameters
      }
    }
  end
end

class Hash
  def fnjoin(separator = "")
    {
      "Fn::Join": [
        separator,
        self
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
end

class String
  def cfnize
    return self if self !~ /_/ && self =~ /[A-Z]+.*/
    split("_").map(&:capitalize).join
  end

  def get_output(attr)
    attr = attr.class == String ? attr : attr.to_s.split("_").map(&:capitalize).join
    {
      "Fn::GetAtt": [
        to_s.split("_").map(&:capitalize).join, "Outputs.#{attr}"
      ]
    }
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

  def fntransform(parameters = nil)
    raise "fntransform parameters must be of type Hash" unless parameters.class == Hash
    {
      "Fn::Transform": {
        "Name": self,
        "Parameters": parameters
      }
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
  # rubocop:disable Style/CaseEquality
  # rubocop:disable Lint/UnusedBlockArgument
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
    self.merge(second.to_h, &merger)
  end
  # rubocop:enable Style/CaseEquality
  # rubocop:enable Lint/UnusedBlockArgument

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

  def fnjoin(separator = "")
    {
      "Fn::Join": [
        separator,
        self
      ]
    }
  end
end
