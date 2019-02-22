module Shoden
  Proxy = Struct.new(:klass, :parent) do
    def create(args = {})
      klass.create(args.merge(key => parent.id))
    end

    def all
      klass.filter(parent_filter)
    end

    def count
      row = klass.query(fields: "COUNT(id)", conditions: parent_filter)
      row.first["count"].to_i
    end

    def any?
      count > 0
    end

    def first
      filter = { order: "id ASC LIMIT 1" }.merge!(parent_filter)
      klass.filter(filter).first
    end

    def last
      filter = { order: "id DESC LIMIT 1" }.merge!(parent_filter)
      klass.filter(filter).first
    end

    def [](id)
      filter = { id: id }.merge!(parent_filter)

      klass.filter(filter).first
    end

    private

    def parent_filter
      { key => parent.id }
    end

    def key
      "#{parent.class.to_reference}_id".freeze
    end
  end
end
