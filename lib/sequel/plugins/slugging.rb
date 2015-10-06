require 'sequel/plugins/slugging/version'

module Sequel
  module Plugins
    module Slugging
      def self.configure(model, opts={})
        model.instance_eval do
          @slugging_opts = opts
        end
      end

      module ClassMethods
      end

      module InstanceMethods
      end

      module DatasetMethods
      end
    end
  end
end
