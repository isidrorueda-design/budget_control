# frozen_string_literal: true

class BcBaseBudget < ActiveRecord::Base
  include BudgetControl::ProjectScoped

  belongs_to :project
  belongs_to :bc_item, class_name: 'BcItem'

  validates :project_id, presence: true
  validates :bc_item_id, presence: true, uniqueness: { scope: :project_id, message: 'ya tiene un presupuesto base asignado para este proyecto' }
  validates :budget_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
end