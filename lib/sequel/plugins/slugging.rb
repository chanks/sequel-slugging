require 'securerandom'
require 'set'

require 'sequel/plugins/slugging/version'

module Sequel
  module Plugins
    module Slugging
      UUID_REGEX = /\A[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/

      class << self
        attr_writer :slugifier, :maximum_length

        def slugifier
          @slugifier ||= proc do |string|
            s = string.downcase
            s.gsub!(/[^a-z\-_]+/, '-'.freeze)
            s.gsub!(/-{2,}/, '-'.freeze)
            s.gsub!(/^-|-$/, ''.freeze)
            s
          end
        end

        def maximum_length
          @maximum_length ||= 50
        end

        attr_reader :reserved_words

        def reserved_words=(value)
          @reserved_words = Set.new(value)
        end
      end

      def self.configure(model, source:)
        model.instance_eval do
          @slugging_opts = {source: source}.freeze
        end
      end

      module ClassMethods
        attr_reader :slugging_opts

        Sequel::Plugins.inherited_instance_variables(self, :@slugging_opts => ->(h){h.dup.freeze})
        Sequel::Plugins.def_dataset_methods(self, [:from_slug, :from_slug!])
      end

      module InstanceMethods
        private

        def before_save
          set_slug
          super
        end

        def set_slug
          self.slug = find_available_slug
        end

        def find_available_slug
          string = send(self.class.slugging_opts[:source])

          return SecureRandom.uuid if string.nil? || string == ''.freeze

          string = Sequel::Plugins::Slugging.slugifier.call(string)
          string = string.slice(0...Sequel::Plugins::Slugging.maximum_length)

          if acceptable_slug?(string)
            string
          else
            string << '-'.freeze << SecureRandom.uuid
          end
        end

        def acceptable_slug?(slug)
          reserved = Sequel::Plugins::Slugging.reserved_words
          return false if reserved && reserved.include?(slug)
          self.class.dataset.where(slug: slug).empty?
        end
      end

      module DatasetMethods
        def from_slug(id_or_slug)
          m      = model
          pk     = m.primary_key
          schema = m.db_schema[pk]

          if schema[:type] == :integer
            case id_or_slug
            when String
              if id_or_slug =~ /\A\d{1,}\z/
                where(id: id_or_slug.to_i).first
              else
                where(slug: id_or_slug).first
              end
            when Integer
              where(pk => id_or_slug).first
            else
              raise "Argument to Dataset#from_slug needs to be a String or Integer"
            end
          elsif schema[:db_type] == 'uuid'.freeze
            record = where(slug: id_or_slug).first
            return record if record

            if id_or_slug =~ UUID_REGEX
              where(pk => id_or_slug).first
            end
          else
            raise "#from_slug can't handle this pk: #{pk_schema.inspect}"
          end
        end

        def from_slug!(id_or_slug)
          from_slug(id_or_slug) || raise(Sequel::NoMatchingRow)
        end
      end
    end
  end
end
