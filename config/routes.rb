# plugins/budget_control/config/routes.rb
RedmineApp::Application.routes.draw do
  # Ignora la petición del favicon para evitar errores de enrutamiento en los logs
  get 'favicon.ico', to: proc { [204, {}, []] }

  scope '/projects/:project_id' do
       # Ruta principal del plugin (pestaña "Presupuestos") y recursos anidados
    get 'budget_control', to: 'bc/budget_control#index', as: 'bc_budget_control'
    namespace :bc do
      resources :contractors do
        collection { post :import; get :export }
      end
      resources :contracts do
        collection { post :import; get :export }
      end
      resources :items
      resources :estimates do
        collection { post :import; get :export; get :contracts }
      end
    end
  end
end
