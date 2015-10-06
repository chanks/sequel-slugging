require 'sequel/plugins/slugging/version'

module Sequel
  module Plugins
    module Slugging
      def self.configure(model, opts={})
        model.instance_eval do
          @slugging_opts = opts.freeze
        end
      end

      module ClassMethods
        attr_reader :slugging_opts
      end

      module InstanceMethods
        private

        def before_save
          set_slug
          super
        end

        def set_slug
          string = send(self.class.slugging_opts[:source]).downcase
          string.gsub!(/[^a-z0-9\-_]+/, '-'.freeze)
          string.gsub!(/-{2,}/, '-'.freeze)
          string.gsub!(/^-|-$/, ''.freeze)
          self.slug = string
        end
      end

      module DatasetMethods
      end
    end
  end
end
