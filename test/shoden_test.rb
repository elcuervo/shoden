require 'cutest'
require 'shoden'

Model = Class.new(Shoden::Model)

class User < Shoden::Model
  attribute :name
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
