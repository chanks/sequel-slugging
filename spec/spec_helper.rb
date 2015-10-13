$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'minitest/autorun'
require 'minitest/hooks'

require 'sequel'

DB = Sequel.connect("postgres:///sequel-slugging-test")

DB.run 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp"'

DB.drop_table? :widgets

DB.create_table :widgets do
  primary_key :id

  text :name, null: false
  text :other_text
  text :more_text
  text :slug, null: false, unique: true
end

DB.drop_table? :slug_history

DB.create_table :slug_history do
  primary_key :id
  text :slug, null: false
  integer :sluggable_id, null: false
  text :sluggable_type, null: false
  timestamptz :created_at, null: false
end
