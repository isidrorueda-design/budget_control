class BcItem < ActiveRecord::Base
  include BudgetControl::ProjectScoped
  has_many :contracts, class_name: 'BcContract', dependent: :restrict_with_error
  has_one :bc_base_budget, class_name: 'BcBaseBudget', foreign_key: 'bc_item_id', dependent: :destroy

  validates :code, presence: true, uniqueness: { scope: :project_id }
  validates :unit, presence: true
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def total
    (unit_price || 0) * (quantity || 0)
  end

  def code_and_description
    "#{code} - #{description}"
  end
end
