# frozen_string_literal: true
module BudgetControl
  module ProjectScoped
    extend ActiveSupport::Concern

    included do
      belongs_to :project, class_name: 'Project'

      scope :of_project, ->(proj) { where(project_id: proj) }
      validates  :project_id, presence: true
    end

    # helpers opcionales
    def project_name
      project&.name
    end
  end
end