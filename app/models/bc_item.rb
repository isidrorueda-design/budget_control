class BcItem < ActiveRecord::Base
  include BudgetControl::ProjectScoped
  has_many :contracts, class_name: 'BcContract', dependent: :restrict_with_error
  has_one :bc_base_budget, class_name: 'BcBaseBudget', foreign_key: 'bc_item_id', dependent: :destroy
  validates :code, presence: true, uniqueness: { scope: :project_id }
    def code_and_description
    "#{code} - #{description}"
  end
end