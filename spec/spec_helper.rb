$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'minitest/autorun'
require 'minitest/hooks'

require 'sequel'

DB = Sequel.sqlite

DB.create_table :widgets do
  primary_key :id

  text :name, null: false
  text :slug, null: false, unique: true
end
