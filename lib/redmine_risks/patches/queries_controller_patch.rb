require_dependency 'queries_controller'

module RedmineRisks
  module Patches
    module QueriesControllerPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)
        base.class_eval do
            unloadable # Send unloadable so it will not be unloaded in development
            def redirect_to_risk_query(options)
                redirect_to risk_path(@risk)
            end
        end
      end
      module InstanceMethods
        #
      end
    end
  end
end

unless QueriesController.included_modules.include?(RedmineRisks::Patches::QueriesControllerPatch)
    QueriesController.send(:include, RedmineRisks::Patches::QueriesControllerPatch)
end
