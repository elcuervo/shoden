require 'cutest'
require 'spirit'

test 'connect' do
  Spirit.connect
  assert Spirit.connected?
end

test 'model' do
  Model = Class.new(Spirit::Model)

  model = Model.create
  assert model.id
end

test 'attributes' do
  class User < Spirit::Model
    attribute :name
  end

  user = User.create name: 'Michel'
  assert_equal user.name, 'Michel'
end
