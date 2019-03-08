require "json"
require "shoden/proxy"

module Shoden
  class Model
    attr_reader :attributes

    def initialize(attrs = {})
      @_id = attrs.delete(:id) if attrs[:id]
      @attributes = {}
      update(attrs)
    end

    def id
      return nil unless defined?(@_id)
      @_id.to_i
    end

    def destroy
      query = "DELETE FROM \"#{self.class.table_name}\" WHERE id = $1 RETURNING id"
      ret = Shoden.connection.exec_params(query, [id])
      ret.first["id"]
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
      data = self.class.from_json(ret.first["data"])
      update(data)

      self
    end

    def self.inherited(model)
      Shoden.models.add(model)
    end

    def self.save(record)
      if record.id
        query = "UPDATE \"#{table_name}\" SET data = $1 WHERE id = $2"
        Shoden.connection.exec_params(query, [record.attributes, record.id])
      else
        begin
          query = "INSERT INTO \"#{table_name}\" (data) VALUES ($1) RETURNING id"
          res = Shoden.connection.exec_params(query, [record.attributes.to_json])
          record.instance_variable_set(:@_id, res.first["id"])
        rescue PG::UniqueViolation
          raise Shoden::UniqueIndexViolation
        end
      end
    end

    def self.all
      collect
    end

    def self.count
      query = "SELECT COUNT(*) FROM \"#{table_name}\""
      Shoden.connection.exec(query).first["count"].to_i
    end

    def self.first
      collect(order: "id ASC", limit: 1).first
    end

    def self.last
      collect(order: "id DESC", limit: 1).first
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
      indices << name unless indices.include?(name)
    end

    def self.unique(name)
      uniques << name unless uniques.include?(name)
    end

    def self.attribute(name, caster = ->(x) { x })
      attributes << name unless attributes.include?(name)

      define_method(name) { caster[@attributes[name]] }
      define_method(:"#{name}=") { |value| @attributes[name] = value }
    end

    def self.collection(name, model)
      define_method(name) do
        klass = Kernel.const_get(model)
        Shoden::Proxy.new(klass, self)
      end
    end

    def self.reference(name, model)
      reader = :"#{name}_id"
      writer = :"#{name}_id="

      attributes << name unless attributes.include?(name)

      define_method(reader) { @attributes[reader] }
      define_method(writer) { |value| @attributes[reader] = value }

      define_method(name) do
        klass = Kernel.const_get("Shoden::#{model}")
        klass[send(reader)]
      end
    end

    def self.filter(conditions = {})
      rows = query(conditions: conditions)

      rows.lazy.map do |row|
        data = from_json(row["data"])
        data[:id] = row["id"].to_i

        new(data)
      end
    end

    def self.query(fields: "*", conditions: {})
      id = conditions.delete(:id)
      order = conditions.delete(:order)

      if id && conditions.none?
        sql = "#{base_query(fields)} WHERE id = $1"
        Shoden.connection.exec_params(sql, [id]) || []
      else
        count = conditions.count
        where = count.times.map { |i| "data->>$#{2 * i + 1} = $#{2 * i + 2}" }
        params = conditions.flatten

        if id
          where << "id = $#{count * 2 + 1}"
          params << id
        end

        where = where.join(" AND ")
        order_condition = "ORDER BY #{order}" if order
        sql = "#{base_query(fields)} WHERE #{where} #{order_condition}"

        Shoden.connection.exec_params(sql, params) || []
      end
    end

    private

    def self.from_json(string)
      JSON.parse(string, symbolize_names: true)
    end

    def self.base_query(fields = "*")
      "SELECT #{fields} FROM \"#{table_name}\""
    end

    def self.collect(order: :id, limit: 0)
      query = base_query("*")

      params = [].tap do |item|
        item << order
        query << " ORDER BY $1"

        if limit > 0
          item << limit
          query << " LIMIT $2 "
        end
      end

      [].tap do |records|
        Shoden.connection.exec_params(query, params).each do |row|
          data = from_json(row["data"])
          data[:id] = row["id"].to_i

          records << new(data)
        end
      end
    end

    def self.table_name
      :"Shoden::#{name}"
    end

    def self.to_reference
      name.to_s
          .match(/^(?:.*::)*(.*)$/)[1]
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase.to_sym
    end

    def self.create_index(name, type = "")
      query = <<~EOS
        CREATE #{type.upcase} INDEX index_#{self.name}_#{name}
        ON "#{table_name}" (( data ->> '#{name}'))
        WHERE ( data ? '#{name}' );
      EOS

      Shoden.connection.exec(query)
    end

    def self.lookup(id)
      query = "SELECT * FROM \"#{table_name}\" WHERE id = $1"
      row = Shoden.connection.exec_params(query, [id])
      return nil if row.none?

      row
    end

    def self.setup
      Shoden.connection.exec <<~EOS
        CREATE TABLE IF NOT EXISTS \"#{table_name}\" (
          id   SERIAL NOT NULL PRIMARY KEY,
          data JSONB
        )
      EOS

      indices.each { |i| create_index(i) }
      uniques.each { |i| create_index(i, :unique) }
    end

    def self.destroy_all
      Shoden.connection.exec("DELETE FROM \"#{table_name}\"")
    end

    def self.destroy_table
      Shoden.connection.exec("DROP TABLE IF EXISTS \"#{table_name}\"")
    end
  end
end
