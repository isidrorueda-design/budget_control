# frozen_string_literal: true

Redmine::Plugin.register :budget_control do
  name        'Budget Control'
  author      'Isidro Rueda'
  description 'Plugin para control de presupuestos, contratos y estimaciones'
  version     '0.0.3'
  requires_redmine :version_or_higher => '5.0.0'

  project_module :budget_control do
    permission :view_budget_control,
               { 'bc/budget_control': [:index],
                 'bc/contractors':    [:index],
                 'bc/contracts':      [:index],
                 'bc/items':          [:index],
                 'bc/estimates':      [:index, :contracts] },
               public: true

    permission :manage_budget_control,
               { 'bc/contractors': [:new, :create, :edit, :update, :destroy, :import, :export],
                 'bc/items':       [:new, :create, :edit, :update, :destroy],
                 'bc/contracts':   [:new, :create, :edit, :update, :destroy, :import, :export],
                 'bc/estimates':   [:new, :create, :edit, :update, :destroy, :import, :export] }
  end

  menu :project_menu, :budget_control,
       { controller: 'bc/budget_control', action: 'index' },
       caption:  'Presupuestos',
       param:    :project_id,
       after:    :activity,
       if:       ->(p) { User.current.allowed_to?(:view_budget_control, p) }
end

# Carga segura de parches y dependencias
Rails.configuration.to_prepare do
  require_dependency 'budget_control/project_scoped'
  require_dependency 'budget_control/patches/project_patch'
  require_dependency 'budget_control/hooks'
end