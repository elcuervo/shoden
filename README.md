# Shôden - [![Gem Version](https://badge.fury.io/rb/shoden.svg)](http://badge.fury.io/rb/shoden)

![Elephant god](http://www.redprintdna.com/wp-content/uploads/2011/09/L-Elephant-Against-Sky.jpg)

Shôden is a persistance library on top of Postgres.
It is basically an [Ohm](https://github.com/soveran/ohm) clone but using
Postgres as a main database.

## Installation

```bash
gem install shoden
```

## Models

```ruby
class Fruit < Shoden::Model
  attribute :type
end
```

```ruby
Fruit.create type: "Banana"
```

To find by an id:

```ruby
Fruit[1]
```

## Relations

```ruby
class User < Shoden::Model
  attribute :email

  collection :posts, :Post
end

class Post < Shoden::Model
  attribute :title
  attribute :content

  reference :owner, :User
end
```
