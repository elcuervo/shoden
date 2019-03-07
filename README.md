# Shôden - [![Build Status](https://travis-ci.org/elcuervo/shoden.svg)](https://travis-ci.org/elcuervo/shoden)

![Elephant god](https://images.unsplash.com/photo-1523190301657-195ef118bb36?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1500&q=80)

Shôden is a persistance library on top of Postgres.
It is basically an [Ohm](https://github.com/soveran/ohm) clone but using
Postgres as a main database.

## Installation

```bash
gem install shoden
```

## Connect

Shoden connects by default using a `DATABASE_URL` env variable.
But you can change the connection string by calling `Shoden.url=`

## Setup

Shoden needs a setup method to create the proper tables.
You should do that after connecting

```ruby
Shoden.setup
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

## Attributes

Shoden attributes offer you a way to type cast the values, or to perform changes
in the data itself.

```ruby
class Shout < Shoden::Model
  attribute :what, ->(x) { x.uppcase }
end
```

## Indexing

```ruby
class User < Shoden::Model
  attribute :email
  attribute :country

  index  :country
  unique :email
end
```

## Querying

You can query models or relations using the `filter` method.

```ruby
User.filter(email: "elcuervo@elcuervo.net")
User.first
User.last
User.count
```

You can go through the entire set using: `User.all` which will give you a
`Enumerator::Lazy`
