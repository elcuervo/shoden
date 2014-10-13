require 'pg'

module Spirit
  def self.connect
  end

  def self.connected?
    true
  end

  class Model
    def initialize(attrs = {})
      @attributes = {}
      update_attributes(attrs)
    end

    def id
      1
    end

    def update_attributes(attrs)
      attrs.each { |name, value| send(:"#{name}=", value) }
    end

    def self.create(attrs = {})
      new(attrs)
    end

    def self.attribute(name)
      define_method(name) { @attributes[name] }
      define_method(:"#{name}=") { |value| @attributes[name] = value }
    end
  end
end
