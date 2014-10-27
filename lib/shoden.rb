require 'sequel'

Sequel.extension :pg_hstore, :pg_hstore_ops

module Shoden
  MissingID = Class.new(StandardError)
  NotFound  = Class.new(StandardError)

  Proxy = Struct.new(:klass, :parent) do
    def create(args = {})
      key = "#{parent.class.to_reference}_id"
      klass.create(args.merge(
        key => parent.id
      ))
    end
  end

  def self.url=(url)
    @_url = url
  end

  def self.url
    @_url ||= ENV['DATABASE_URL']
  end

  def self.connection
    @_connection ||= Sequel.connect(url)
  end

  def self.destroy_all
    connection.tables.select do |t|
      connection.drop_table(t) if t.to_s.start_with?('Shoden::')
    end
  end

  class Model
    def initialize(attrs = {})
      @_id = attrs.delete(:id) if attrs[:id]
      @attributes = Sequel::Postgres::HStore.new({})
      update(attrs)
    end

    def id
      raise MissingID if !defined?(@_id)
      @_id.to_i
    end

    def destroy
      lookup(id).delete
    end

    def update(attrs = {})
      attrs.each { |name, value| send(:"#{name}=", value) }
    end

    def update_attributes(attrs = {})
      update(attrs)
      save
    end

    def save
      if defined? @_id
        table.where(id: @_id).update data: @attributes
      else
        @_id = table.insert data: @attributes
      end

      self
    end

    def load!
      ret = lookup(@_id)
      update(ret.to_a.first[:data])
      self
    end

    def self.create(attrs = {})
      new(attrs).save
    end

    def self.[](id)
      new(id: id).load!
    end

    def self.attribute(name, caster = nil)
      if caster
        define_method(name) { caster[@attributes[name]] }
      else
        define_method(name) { @attributes[name] }
      end

      define_method(:"#{name}=") { |value| @attributes[name] = value }
    end

    def self.collection(name, model)
      define_method(name) do
        klass = Kernel.const_get(model)
        Proxy.new(klass, self)
      end
    end

    def self.reference(name, model)
      reader = :"#{name}_id"
      writer = :"#{name}_id="

      define_method(reader) { @attributes[reader] }
      define_method(writer) { |value| @attributes[reader] = value }

      define_method(name) do
        klass = Kernel.const_get("Shoden::#{model}")
        klass[send(reader)]
      end
    end

    private

    def self.to_reference
      name.to_s.
        match(/^(?:.*::)*(.*)$/)[1].
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        downcase.to_sym
    end

    def lookup(id)
      raise NotFound if !conn.tables.include?(table_name.to_sym)

      row = table.where(id: id)
      raise NotFound if !row.any?

      row
    end

    def setup
      Shoden.connection.execute("CREATE EXTENSION IF NOT EXISTS hstore")
      Shoden.connection.create_table? table_name do
        primary_key :id
        hstore      :data
      end
    end

    def table_name
      :"Shoden::#{self.class.name}"
    end

    def table
      conn[table_name]
    end

    def conn
      c = Shoden.connection
      @created ||= setup
      c
    end
  end
end
