#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler'

Bundler.require

require 'benchmark/ips'

require 'rom-sql'

require 'active_record'

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => ":memory:"
)

ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string :name
    t.string :email
    t.integer :age
  end
end

class ARUser < ActiveRecord::Base
  self.table_name = :users
end

def env
  ROM_ENV
end

setup = ROM.setup(sqlite: 'sqlite::memory')

setup.sqlite.connection.run("CREATE TABLE users (id SERIAL, name STRING, email STRING, age INT)")

setup.relation(:users) do
  def all
    order(:id)
  end

  def user_json
    all
  end
end

setup.mappers do
  define(:users) do
    model name: 'User'
  end

  define(:user_json, parent: :users)
end

ROM_ENV = setup.finalize

COUNT = ENV.fetch('COUNT', 1000).to_i

SEED = COUNT.times.map do |i|
  { :id    => i + 1,
    :name  => "name #{i}",
    :email => "email_#{i}@domain.com",
    :age   => i*10 }
end

def seed
  SEED.each do |attributes|
    env.schema.users.insert(attributes)
    ARUser.create(attributes)
  end
end

seed

puts "LOADED #{env.schema.users.count} users via ROM/Sequel"
puts "LOADED #{ARUser.count} users via ActiveRecord"

puts "AAAAAAA: #{ROM_ENV.read(:users).user_json.to_a.inspect}"
puts "AAAAAAA: #{ARUser.all.to_a.map(&:as_json).inspect}"

USERS = ROM_ENV.read(:users).all

Benchmark.ips do |x|
  x.report("rom.read(:users).all.to_a") { USERS.to_a }
  x.report("ARUser.all.to_a") { ARUser.all.to_a }
  x.report("rom.read(:user_json).all.to_a") { ROM_ENV.read(:users).user_json.to_a }
  x.report("ARUser.all.map(&:as_json)") { ARUser.all.map(&:as_json) }
end
