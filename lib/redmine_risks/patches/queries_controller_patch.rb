require_dependency 'journal'

module RedmineRisks
  module Patches
    module QueriesControllerPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)
        end
      end

      module InstanceMethods
        #
        def redirect_to_risk_query(options)
            redirect_to risk_path(@risk)
        end
      end
    end
  end
end

unless QueriesController.included_modules.include?(RedmineRisks::Patches::QueriesControllerPatch)
    QueriesController.send(:include, RedmineRisks::Patches::QueriesControllerPatch)
end
