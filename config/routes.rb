RedmineApp::Application.routes.draw do
  resources :sites do
    collection do
      get 'search'
      get 'autocomplete'  # Agregar ruta alternativa
      get 'export'
      get 'import'
      post 'import'
      get 'download_template'
      post 'bulk_update'
    end
    member do
      post 'toggle_status'
    end
  end
end