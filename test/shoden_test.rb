require "cutest"
require "simplecov"

SimpleCov.start

require "shoden"

Model = Class.new(Shoden::Model)

class Person < Shoden::Model
  attribute :email
  attribute :origin

  index  :origin
  unique :email
end

class Tree < Shoden::Model
  attribute  :name
  collection :sprouts, :Sprout
end

class Sprout < Shoden::Model
  attribute :leaves
  reference :tree, :Tree
end

class User < Shoden::Model
  attribute :name
end

class A < Shoden::Model
  attribute :n, ->(x) { x.to_i }
end

setup do
  Shoden.destroy_tables
  Shoden.setup
end

test "url setup" do
  Shoden.url = ENV["DATABASE_URL"]
end

test "model" do
  model = Model.create

  assert Model.count
  assert_equal model.id.class, Integer
end

test "attributes" do
  user = User.create name: "Michel"
  assert_equal user.name, "Michel"
end

test "update" do
  user = User.create name: "Cyril"
  id = user.id

  assert_equal user.name, "Cyril"

  user.name = "cyx"
  user.save

  assert_equal user.name, "cyx"
  assert_equal user.id, id

  user.update_attributes(name: "Cyril")
  assert_equal user.name, "Cyril"
end

test "filtering" do
  person = { email: "edgar@poe.com" }
  Person.create(person)
  p = Person.filter(person).first

  assert p.email == "edgar@poe.com"
end

test "relations" do
  tree = Tree.create(name: "asd")
  tree2 = Tree.create(name: "qwe")

  assert tree.id
  assert_equal tree.name, "asd"

  sprout = tree.sprouts.create(leaves: 4)
  tree2.sprouts.create(leaves: 5)

  assert sprout.is_a?(Sprout)
  assert tree.sprouts.all.each.is_a?(Enumerator)

  assert tree.sprouts[sprout.id].id == sprout.id

  assert tree.sprouts.any?
  assert_equal tree.sprouts.count, 1
  assert_equal sprout.tree.id, tree.id
  assert !tree.sprouts.first.nil?
  assert !tree.sprouts.last.nil?
end

test "deletion" do
  user = User.create(name: "Damian")
  id = user.id

  user.destroy

  assert_equal User[id], nil
end

test "casting" do
  a = A.create(n: 1)
  a_prime = A[a.id]

  assert_equal a_prime.n, 1
end

test "indices" do
  person = Person.create(email: "edgar@poe.com", origin: "The internerd")

  assert person.id

  assert_raise Shoden::UniqueIndexViolation do
    Person.create(email: "edgar@poe.com", origin: "Montevideo City")
  end
end

test "basic querying" do
  User.destroy_all
  5.times { User.create }

  assert User.query(conditions: { id: 1 })
  assert User.first != User.last
  assert_equal User.all.size, 5
end
