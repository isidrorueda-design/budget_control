# frozen_string_literal: true

# Este parche extiende el modelo Project de Redmine para incluir
# las asociaciones has_many con los modelos del plugin BudgetControl.

require_dependency 'project'

module BudgetControl
  module Patches
    module ProjectPatch
      def self.included(base)
        base.class_eval do
          # Asociaciones con los modelos del plugin
          has_many :bc_items,       class_name: 'BcItem',       dependent: :destroy
          has_many :bc_contractors, class_name: 'BcContractor', dependent: :destroy
          has_many :bc_contracts,   class_name: 'BcContract',   dependent: :destroy
          has_many :bc_estimates,   class_name: 'BcEstimate',   dependent: :destroy
        end
      end
    end
  end
end

# Aplica el parche al modelo Project de Redmine de forma segura
unless Project.included_modules.include?(BudgetControl::Patches::ProjectPatch)
  Project.send(:include, BudgetControl::Patches::ProjectPatch)
end
