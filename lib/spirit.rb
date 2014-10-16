require 'sequel'

Sequel.extension :pg_hstore, :pg_hstore_ops

module Spirit
  MissingID = Class.new(StandardError)

  def self.connect(url = ENV['DATABASE_URL'])
    @_url = url
  end

  def self.database_url
    @_url ||= ENV['DATABASE_URL']
  end

  def self.connection
    @_connection ||= Sequel.connect(database_url)
  end

  class Model
    def initialize(attrs = {})
      @attributes = Sequel.hstore({})
      update_attributes(attrs)
    end

    def id
      raise MissingID if !defined?(@_id)
      @_id
    end

    def update_attributes(attrs)
      attrs.each { |name, value| send(:"#{name}=", value) }
    end

    def table_name
      self.class.name.to_sym
    end

    def conn
      Spirit.connection
    end

    def save
      conn.execute("CREATE EXTENSION IF NOT EXISTS hstore")
      conn.create_table? table_name do
        primary_key :id
        hstore      :data
      end

      table = conn[table_name]

      if defined? @_id
        table.update data: @attributes
      else
        @_id = table.insert data: @attributes
      end

      self
    end

    def self.create(attrs = {})
      new(attrs).save
    end

    def self.attribute(name)
      define_method(name) { @attributes[name] }
      define_method(:"#{name}=") { |value| @attributes[name] = value }
    end
  end
end
