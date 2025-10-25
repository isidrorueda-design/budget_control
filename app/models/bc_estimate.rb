# frozen_string_literal: true

class BcEstimate < ActiveRecord::Base
  include BudgetControl::ProjectScoped
  belongs_to :contractor, class_name: 'BcContractor'
  belongs_to :contract, class_name: 'BcContract' # Rails usará 'contract_id' por convención, que es lo correcto.

  before_save :calculate_totals

  validates :contractor_id, :contract_id, presence: true
  validates :estimated, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :estimate_num, uniqueness: { scope: :contract_id }

  private

  def calculate_totals
    self.total_estimated = estimated.to_d - amortized.to_d - warranty_fund.to_d - retentions.to_d - deductive.to_d
    self.iva = contract&.apply_iva ? (total_estimated * 0.16) : 0
    self.total = total_estimated + iva
  end
end