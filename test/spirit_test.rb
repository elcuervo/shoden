require 'cutest'
require 'spirit'

setup do
  Spirit.connect
end

Model = Class.new(Spirit::Model)

class User < Spirit::Model
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
  user = User.create name: 'Ciril'
  id = user.id

  assert_equal user.name, 'Ciril'

  user.name = 'cyx'
  user.save

  assert_equal user.name, 'cyx'
  assert_equal user.id, id
end
