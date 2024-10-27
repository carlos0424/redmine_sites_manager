RedmineApp::Application.routes.draw do
  resources :sites do
    member do
      patch 'actualizar'  # Cambiado
      post 'toggle_status'
    end
    collection do
      get 'search'
      post 'import'
      get 'download_template'
      post 'bulk_update'
    end
  end
end