# frozen_string_literal: true
module Bc
  class BaseBudgetsController < ::BudgetControl::ApplicationController
    before_action :set_base_budget, only: %i[edit update destroy]
    before_action :set_items_for_select, only: %i[new create edit update]

    def index
      @items = @project.bc_items.includes(:bc_base_budget).order(:code)

      # Preload contract totals for all items to avoid N+1 queries for contract sums
      # This will create a hash like { item_id => sum_of_total_with_iva }
      # The `total_with_iva` column is stored in the database, so we can sum it directly.
      contract_totals_by_item = @project.bc_contracts
                                        .group(:item_id)
                                        .sum(:total_with_iva)

      @budget_data = @items.map do |item|
        base_budget = item.bc_base_budget&.budget_amount || 0.0
        contracts_total = contract_totals_by_item[item.id] || 0.0

        difference = contracts_total - base_budget
        # Handle division by zero for percentage calculation
        percentage_difference = (base_budget != 0) ? (difference / base_budget * 100) : (difference == 0 ? 0 : nil)

        {
          item: item,
          base_budget: base_budget,
          contracts_total: contracts_total,
          difference: difference,
          percentage_difference: percentage_difference
        }
      end

      # Calcular totales para la fila de resumen
      total_base_budget = @budget_data.sum { |d| d[:base_budget] }
      total_contracts_total = @budget_data.sum { |d| d[:contracts_total] }
      total_difference = total_contracts_total - total_base_budget
      total_percentage_difference = (total_base_budget != 0) ? (total_difference / total_base_budget * 100) : (total_difference == 0 ? 0 : nil)

      @totals = {
        base_budget: total_base_budget,
        contracts_total: total_contracts_total,
        difference: total_difference,
        percentage_difference: total_percentage_difference
      }
    end

    def new
      @base_budget = @project.bc_base_budgets.build
      # Pre-select item if passed in params (e.g., from index page's "Assign" link)
      @base_budget.bc_item_id = params[:bc_item_id] if params[:bc_item_id].present?
    end

    def create
      @base_budget = @project.bc_base_budgets.build(base_budget_params)
      if @base_budget.save
        flash[:notice] = 'Presupuesto base creado correctamente.'
        redirect_to bc_base_budgets_path(project_id: @project)
      else
        render :new
      end
    end

    def edit
      # @base_budget is set by before_action
    end

    def update
      if @base_budget.update(base_budget_params)
        flash[:notice] = 'Presupuesto base actualizado correctamente.'
        redirect_to bc_base_budgets_path(project_id: @project)
      else
        render :edit
      end
    end

    def destroy
      if @base_budget.destroy
        flash[:notice] = 'Presupuesto base eliminado correctamente.'
      else
        flash[:error] = @base_budget.errors.full_messages.to_sentence
      end
      redirect_to bc_base_budgets_path(project_id: @project)
    end

    private

    def base_budget_params
      params.require(:bc_base_budget).permit(:bc_item_id, :budget_amount)
    end

    def set_base_budget
      @base_budget = scoped_relation(BcBaseBudget).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:error] = 'Presupuesto base no encontrado.'
      redirect_to bc_base_budgets_path(project_id: @project)
    end

    def set_items_for_select
      # Only show items that don't already have a base budget for this project,
      # or the item associated with the current @base_budget if editing.
      existing_item_ids = @project.bc_base_budgets.pluck(:bc_item_id)
      @items_for_select = @project.bc_items.where.not(id: existing_item_ids).order(:code)
      @items_for_select = @items_for_select.or(@project.bc_items.where(id: @base_budget.bc_item_id)) if @base_budget&.persisted?
    end
  end
end