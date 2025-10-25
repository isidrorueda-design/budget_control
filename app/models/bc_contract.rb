# frozen_string_literal: true

class BcContract < ActiveRecord::Base
  include BudgetControl::ProjectScoped

  belongs_to :contractor, class_name: 'BcContractor'
  belongs_to :item, class_name: 'BcItem'

  has_many :estimates, class_name: 'BcEstimate', dependent: :restrict_with_error

  # Validaciones
  validates :number, presence: true, uniqueness: { scope: :project_id, message: 'ya existe para este proyecto' }
  validates :contractor, presence: true
  validates :item, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :additives, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :deductives, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :advance, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  before_save :set_calculated_fields

  # Calcula el monto total del contrato
  # Se usa en la exportación a Excel.
  def total_amount
    (amount || 0) + (additives || 0) - (deductives || 0)
  end

  # Override the getter for total_with_iva to ensure it's never nil
  # This method will return the stored value if present, otherwise calculate it.
  # It's important for cases where the column might be nil in the DB.
  def total_with_iva
    read_attribute(:total_with_iva) || calculate_total_with_iva_method
  end

  # Private method to calculate total with IVA
  # This is used if the database column is nil or for fresh calculation
  def calculate_total_with_iva_method
    base_amount = total_amount # This already handles nil for amount, additives, deductives
    if apply_iva
      # Asumiendo una tasa de IVA del 16% (0.16).
      # TODO: Hacer configurable si es necesario, o un atributo del contrato.
      iva_rate = 0.16
      base_amount * (1 + iva_rate)
    else
      base_amount
    end
  end

  # Método helper para obtener el nombre del contratista.
  # Se usa en la respuesta AJAX del controlador de estimaciones.
  def contractor_name
    contractor&.name
  end

  private

  # Callback para asegurar que los campos calculados se establezcan antes de guardar
  def set_calculated_fields
    # Asegura que total_with_iva se calcule y almacene
    self.total_with_iva = calculate_total_with_iva_method

    # Si la columna 'iva' está destinada a almacenar el monto de IVA calculado
    if apply_iva
      iva_rate = 0.16 # TODO: Match with calculate_total_with_iva_method
      self.iva = total_amount * iva_rate
    else
      self.iva = 0.0
    end

    # La columna 'total' parece redundante si total_amount se usa para el cálculo base.
    # Considerar eliminarla de la migración si no se usa explícitamente para otra cosa.
    # self.total = total_amount
  end
end