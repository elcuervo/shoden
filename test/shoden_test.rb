require 'cutest'
require 'shoden'

Model = Class.new(Shoden::Model)

class User < Shoden::Model
  attribute :name
end

setup do
  Shoden.destroy_all
end

test 'model' do
  model = Model.create
  assert_equal model.id.class, Fixnum
end

test 'attributes' do
  user = User.create name: 'Michel'
  assert_equal user.name, 'Michel'
end

test 'update' do
  user = User.create name: 'Cyril'
  id = user.id

  assert_equal user.name, 'Cyril'

  user.name = 'cyx'
  user.save

  assert_equal user.name, 'cyx'
  assert_equal user.id, id

  user.update_attributes(name: 'Cyril')
  assert_equal user.name, 'Cyril'
end

test 'relations' do
  class Tree < Shoden::Model
    attribute   :name
    collection  :sprouts, :Sprout
  end

  class Sprout < Shoden::Model
    attribute :leaves
    reference :tree, :Tree
  end

  tree = Tree.create(name: 'asd')

  assert tree.id
  assert_equal tree.name, 'asd'

  sprout = tree.sprouts.create(leaves: 4)

  assert sprout.is_a?(Sprout)
  assert_equal sprout.tree.id, tree.id
end

test 'deletion' do
  user = User.create(name: 'Damian')
  id = user.id

  user.destroy

  assert_raise(Shoden::NotFound) { User[id] }
end

test 'casting' do
  class A < Shoden::Model
    attribute :n, ->(x) { x.to_i }
  end

  a = A.create(n: 1)
  a_prime = A[a.id]

  assert_equal a_prime.n, 1
end

test 'indices' do
  class Person < Shoden::Model
    attribute :email
    attribute :origin

    index  :origin
    unique :email
  end

  person = Person.create(email: 'elcuervo@elcuervo.net', origin: 'The internerd')

  assert person.id

  assert_raise Shoden::UniqueIndexViolation do
    Person.create(email: 'elcuervo@elcuervo.net', origin: 'The internerd')
  end

end
