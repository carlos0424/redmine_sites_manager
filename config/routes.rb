RedmineApp::Application.routes.draw do
  resources :sites do
    collection do
      get 'sites/search', to: 'sites#search', defaults: { format: 'json' }
      get 'sites/search_local', to: 'sites#search_local', defaults: { format: 'json' }
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