class BcContractor < ActiveRecord::Base
  include BudgetControl::ProjectScoped
  has_many :contracts, class_name: 'BcContract', foreign_key: 'contractor_id', dependent: :restrict_with_error
  # El nombre es requerido y debe ser único por proyecto.
  validates :name, presence: true
  validates :name, uniqueness: { scope: :project_id, case_sensitive: false, message: 'ya existe en este proyecto' }
  # El email es opcional, pero si se proporciona, debe tener un formato válido.
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: 'no es un formato válido', allow_blank: true }
end