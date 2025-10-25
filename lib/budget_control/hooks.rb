# plugins/budget_control/lib/budget_control/hooks.rb
module BudgetControl
  class Hooks < Redmine::Hook::ViewListener
    def view_issues_show_details_bottom(context = {})
      issue = context[:issue]
      return unless issue
      return unless issue.bc_estimate_id.present? || issue.bc_task_cost.present?

      view = context[:controller]&.view_context
      return unless view

      begin
        content = +''.html_safe
        content << view.content_tag(:div, class: 'budget-info box') do
          view.content_tag(:h3, 'Información de Presupuesto') +
          view.content_tag(:table, class: 'attributes') do
            view.content_tag(:tbody) do
              view.content_tag(:tr) do
                view.content_tag(:th, 'Estimación:') +
                view.content_tag(:td, view.link_to(
                  "#{issue.bc_estimate.contract.number} - Est #{issue.bc_estimate.estimate_num}",
                  view.project_bc_estimate_path(issue.project, issue.bc_estimate),
                  class: 'icon icon-money'
                ))
              end +
              view.content_tag(:tr) do
                view.content_tag(:th, 'Costo de la tarea:') +
                view.content_tag(:td, view.number_to_currency(issue.bc_task_cost || 0, unit: "$"))
              end
            end
          end
        end
        content
      rescue => e
        Rails.logger.error "BudgetControlHook error: #{e.class} #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        nil
      end
    end
  end
end
