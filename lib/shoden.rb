require 'sequel'

Sequel.extension :pg_hstore, :pg_hstore_ops

module Shoden
  Error                = Class.new(StandardError)
  MissingID            = Class.new(Error)
  NotFound             = Class.new(Error)
  UniqueIndexViolation = Class.new(Error)

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
      @attributes = {}
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
        table.where(id: @_id).update data: sanitized_attrs
      else
        begin
          @_id = table.insert data: sanitized_attrs
        rescue Sequel::UniqueConstraintViolation
          raise UniqueIndexViolation
        end
      end

      self.class.indices.each { |i| create_index(i) }
      self.class.uniques.each { |i| create_index(i, :unique) }

      self
    end

    def load!
      ret = lookup(@_id)
      update(ret.to_a.first[:data])
      self
    end

    def self.all
      collect
    end

    def self.first
      collect("ORDER BY id ASC LIMIT 1").first
    end

    def self.last
      collect("ORDER BY id DESC LIMIT 1").first
    end

    def self.create(attrs = {})
      new(attrs).save
    end

    def self.attributes
      @attributes ||= []
    end

    def self.indices
      @indices ||= []
    end

    def self.uniques
      @uniques ||= []
    end

    def self.[](id)
      new(id: id).load!
    end

    def self.index(name)
      indices << name if !indices.include?(name)
    end

    def self.unique(name)
      uniques << name if !uniques.include?(name)
    end

    def self.attribute(name, caster = ->(x) { x })
      attributes << name if !attributes.include?(name)

      define_method(name) { caster[@attributes[name]] }
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

      attributes << name if !attributes.include?(name)

      define_method(reader) { @attributes[reader] }
      define_method(writer) { |value| @attributes[reader] = value }

      define_method(name) do
        klass = Kernel.const_get("Shoden::#{model}")
        klass[send(reader)]
      end
    end

    private

    def self.collect(condition = '')
      models = []
      Shoden.connection.fetch("SELECT * FROM \"#{table_name}\" #{condition}") do |r|
        attrs = r[:data].merge(id: r[:id])
        models << new(attrs)
      end
      models
    end

    def self.table_name
      :"Shoden::#{self.name}"
    end

    def self.to_reference
      name.to_s.
        match(/^(?:.*::)*(.*)$/)[1].
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        downcase.to_sym
    end

    def create_index(name, type = '')
      conn.execute <<EOS
        CREATE #{type.upcase} INDEX index_#{self.class.name}_#{name}
        ON "#{table_name}" (( data -> '#{name}'))
        WHERE ( data ? '#{name}' );
EOS
    end

    def sanitized_attrs
      sanitized = @attributes.map do |k, _|
        val = send(k)
        return if !val

        [k, val.to_s]
      end.compact

      Sequel::Postgres::HStore.new(sanitized)
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
      self.class.table_name
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
