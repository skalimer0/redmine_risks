module RedmineRisks
    module Patches
      module DashboardContentProjectPatch
        extend ActiveSupport::Concern
  
        included do
          prepend InstanceOverwriteMethods
        end
  
        module InstanceOverwriteMethods
          def block_definitions
            blocks = super
  
            blocks['risks'] = { label: l(:label_risk_plural),
                                  permission: :view_risks,
                                  no_settings: true,
                                  async: {
                                    cache_expires_in: 600,
                                    skip_user_id: true,
                                    partial: 'dashboards/blocks/project_risks' }
                              }
  
            blocks
          end
        end
      end
    end
  end
  
  if DashboardContentProject.included_modules.exclude? RedmineRisks::Patches::DashboardContentProjectPatch
    DashboardContentProject.include RedmineRisks::Patches::DashboardContentProjectPatch
  end
