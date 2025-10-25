# frozen_string_literal: true
class BudgetControl::ApplicationController < ApplicationController
  before_action :find_project
  helper_method :scoped_relation

  protected

  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # devuelve la relación filtrada por el proyecto actual
  def scoped_relation(klass)
    klass.of_project(@project)
  end
end