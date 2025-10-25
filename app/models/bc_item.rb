class BcItem < ActiveRecord::Base
  include BudgetControl::ProjectScoped
  has_many :contracts, class_name: 'BcContract', dependent: :restrict_with_error
  validates :code, presence: true, uniqueness: { scope: :project_id }
end