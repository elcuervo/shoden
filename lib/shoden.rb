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
    @_url ||= ENV['DATABASE_URL']
  end

  def self.models
    @_models ||= Set.new
  end

  def self.connection
    loggers = []

    if ENV["DEBUG"]
      require 'logger'
      loggers << Logger.new($stdout)
    end

    @_connection ||= begin
      uri = URI.parse(url)
      conn = PG.connect(uri.hostname, uri.port, nil, nil, uri.path[1..-1], uri.user, uri.password)
      conn.set_error_verbosity(PG::PQERRORS_VERBOSE)

      conn
    end
  end

  def self.setup
    models.each { |m| m.setup }
  end

  def self.destroy_tables
    models.each { |m| m.destroy_table }
  end
end
