require 'securerandom'
require 'set'

require 'sequel/plugins/slugging/version'

module Sequel
  module Plugins
    module Slugging
      UUID_REGEX = /\A[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z/
      INTEGER_REGEX = /\A\d{1,}\z/

      class Error < StandardError; end

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

        def pk_type
          schema = db_schema[primary_key]

          if schema[:type] == :integer
            :integer
          elsif schema[:db_type] == 'uuid'.freeze
            :uuid
          else
            raise "The sequel-slugging plugin can't handle this pk type: #{pk_schema.inspect}"
          end
        end
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
          candidates = []

          Array(self.class.slugging_opts[:source]).each do |method_set|
            candidate = Array(method_set).map{|meth| get_slug_component(meth)}.join(' ')
            candidate = Sequel::Plugins::Slugging.slugifier.call(candidate)
            candidate = candidate.slice(0...Sequel::Plugins::Slugging.maximum_length)

            return candidate if acceptable_slug?(candidate)
            candidates << candidate
          end

          candidates.each do |candidate|
            return candidate << '-'.freeze << SecureRandom.uuid if acceptable_string?(candidate)
          end

          SecureRandom.uuid
        end

        def get_slug_component(method)
          case component = send(method)
          when NilClass, String then component
          else raise Error, "unexpected slug component: #{component.inspect}"
          end
        end

        def acceptable_slug?(slug)
          return false unless acceptable_string?(slug)
          reserved = Sequel::Plugins::Slugging.reserved_words
          return false if reserved && reserved.include?(slug)
          self.class.dataset.where(slug: slug).empty?
        end

        def acceptable_string?(string)
          string && string != ''.freeze
        end
      end

      module DatasetMethods
        def from_slug!(pk_or_slug)
          from_slug(pk_or_slug) || raise(Sequel::NoMatchingRow)
        end

        def from_slug(pk_or_slug)
          pk = model.primary_key

          case pk_type = model.pk_type
          when :integer
            case pk_or_slug
            when Integer
              where(pk => pk_or_slug).first
            when String
              if pk_or_slug =~ INTEGER_REGEX
                where(pk => pk_or_slug.to_i).first
              else
                where(slug: pk_or_slug).first
              end
            else
              raise "Argument to Dataset#from_slug needs to be a String or Integer"
            end
          when :uuid
            if record = where(slug: pk_or_slug).first
              record
            elsif pk_or_slug =~ UUID_REGEX
              where(pk => pk_or_slug).first
            end
          else
            raise "Unexpected pk_type: #{pk_type.inspect}"
          end
        end
      end
    end
  end
end
