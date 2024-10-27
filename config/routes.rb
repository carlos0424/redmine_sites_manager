RedmineApp::Application.routes.draw do
  resources :sites do
    collection do
      get 'search', :to => 'sites#search'  
      get 'get_coordinators', to: 'users#get_coordinators'
      post 'import'
      get 'download_template'
      post 'bulk_update'
    end
    member do
      post 'toggle_status'
      patch 'update'  # Añadir la ruta para update
      put 'update'    # También permitir PUT para compatibilidad
    end
  end
end