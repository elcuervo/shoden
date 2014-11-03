require 'sequel'
require 'set'

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

  def self.models
    @_models ||= Set.new
  end

  def self.connection
    @_connection ||= Sequel.connect(url)
  end

  def self.setup
    connection.execute("CREATE EXTENSION IF NOT EXISTS hstore")
    models.each { |m| m.setup }
  end

  def self.destroy_tables
    models.each { |m| m.destroy_table }
  end

  class Model
    def initialize(attrs = {})
      @_id = attrs.delete(:id) if attrs[:id]
      @attributes = {}
      update(attrs)
    end

    def id
      return nil if !defined?(@_id)
      @_id.to_i
    end

    def destroy
      self.class.lookup(id).delete
    end

    def update(attrs = {})
      attrs.each { |name, value| send(:"#{name}=", value) }
    end

    def update_attributes(attrs = {})
      update(attrs)
      save
    end

    def save
      self.class.save(self)
      self
    end

    def load!
      ret = self.class.lookup(@_id)
      return nil if ret.nil?
      update(ret.to_a.first[:data])
      self
    end

    def self.inherited(model)
      Shoden.models.add(model)
    end

    def self.save(record)
      if record.id
        table.where(id: record.id).update(data: record.attributes)
      else
        begin
          id = table.insert(data: record.attributes)
          record.instance_variable_set(:@_id, id)
        rescue Sequel::UniqueConstraintViolation
          raise UniqueIndexViolation
        end
      end
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

    def self.filter(conditions = {})
      query = []
      conditions.each do |k,v|
        query << "data->'#{k}' = '#{v}'"
      end

      row = table.where(query.join("AND"))

      return nil if !row.any?

      new(row.to_a.first[:data])
    end

    def attributes
      sanitized = @attributes.map do |k, _|
        val = send(k)
        return if val.nil?
        [k, val.to_s]
      end.compact

      Sequel::Postgres::HStore.new(sanitized)
    end

    private

    def self.collect(condition = '')
      records = []
      Shoden.connection.fetch("SELECT * FROM \"#{table_name}\" #{condition}") do |r|
        attrs = r[:data].merge(id: r[:id])
        records << new(attrs)
      end
      records
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

    def self.create_index(name, type = '')
      conn.execute <<EOS
        CREATE #{type.upcase} INDEX index_#{self.name}_#{name}
        ON "#{table_name}" (( data -> '#{name}'))
        WHERE ( data ? '#{name}' );
EOS
    end

    def self.lookup(id)
      row = table.where(id: id)
      return nil if !row.any?

      row
    end

    def self.setup
      conn.create_table? table_name do
        primary_key :id
        hstore      :data
      end

      indices.each { |i| create_index(i) }
      uniques.each { |i| create_index(i, :unique) }
    end

    def self.destroy_all
      conn.execute("DELETE FROM \"#{table_name}\"")
    rescue Sequel::DatabaseError
    end

    def self.destroy_table
      conn.drop_table(table_name)
    rescue Sequel::DatabaseError
    end

    def self.table
      conn[table_name]
    end

    def self.conn
      Shoden.connection
    end
  end
end
