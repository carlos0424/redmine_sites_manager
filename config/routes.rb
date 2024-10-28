RedmineApp::Application.routes.draw do
  resources :sites do
    collection do
      get 'search', :to => 'sites#search'  
      get 'export'
      get 'import' # Muestra el formulario de importación
      post 'import' # Procesa el archivo
      get 'download_template'
      post 'bulk_update'
    end
    member do
      post 'toggle_status'
    end
  end
end