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
      end

      module DatasetMethods
      end
    end
  end
end
