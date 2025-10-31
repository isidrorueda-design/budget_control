# frozen_string_literal: true

module Bc
  class ItemsController < ::BudgetControl::ApplicationController
    before_action :set_item, only: %i[edit update destroy]

    def index
      @search = params[:search]
      @items = scoped_relation(BcItem)
      @items = @items.where("code LIKE ? OR description LIKE ?", "%#{@search}%", "%#{@search}%") if @search.present?
      @items = @items.order(:code).page(params[:page]).per(25)
    end

    def new
      @item = @project.bc_items.build
    end

    def create
      @item = @project.bc_items.build(item_params)
      if @item.save
        flash[:notice] = 'Partida creada correctamente.'
        redirect_to bc_items_path(project_id: @project)
      else
        render :new
      end
    end

    def edit
      # @item es cargado por el before_action
    end

    def update
      if @item.update(item_params)
        flash[:notice] = 'Partida actualizada correctamente.'
        redirect_to bc_items_path(project_id: @project)
      else
        render :edit
      end
    end

    def destroy
      if @item.destroy
        flash[:notice] = 'Partida eliminada correctamente.'
      else
        flash[:error] = @item.errors.full_messages.to_sentence
      end
      redirect_to bc_items_path(project_id: @project)
    end

    private

    def item_params
      params.require(:bc_item).permit(:code, :description, :unit, :unit_price, :quantity)
    end

    def set_item
      @item = scoped_relation(BcItem).find(params[:id])
    end
  end
end
