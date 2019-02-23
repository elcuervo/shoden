require "pg"
require "set"
require "shoden/model"

module Shoden
  Error                = Class.new(StandardError)
  MissingID            = Class.new(Error)
  NotFound             = Class.new(Error)
  UniqueIndexViolation = Class.new(Error)

  def self.url=(url)
    @_url = url
  end

  def self.url
    @_url ||= ENV["DATABASE_URL"]
  end

  def self.models
    @_models ||= Set.new
  end

  def self.connection
    @_connection ||= begin
      uri = URI.parse(url)
      PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
    end
  end

  def self.setup
    models.each(&:setup)
  end

  def self.destroy_tables
    models.each(&:destroy_table)
  end
end
