require 'securerandom'

require 'sequel/plugins/slugging/version'

module Sequel
  module Plugins
    module Slugging
      def self.configure(model, source:)
        model.instance_eval do
          @slugging_opts = {source: source}.freeze
        end
      end

      module ClassMethods
        attr_reader :slugging_opts

        Sequel::Plugins.inherited_instance_variables(self, :@slugging_opts => ->(h){h.dup.freeze})
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
          string = send(self.class.slugging_opts[:source]).downcase
          string.gsub!(/[^a-z0-9\-_]+/, '-'.freeze)
          string.gsub!(/-{2,}/, '-'.freeze)
          string.gsub!(/^-|-$/, ''.freeze)

          if self.class.dataset.where(slug: string).empty?
            string
          else
            string << '-'.freeze << SecureRandom.uuid
          end
        end
      end

      module DatasetMethods
      end
    end
  end
end
