RedmineApp::Application.routes.draw do
  resources :sites do
    member do
      post 'update'  # Añadir esta línea
      post 'toggle_status'
    end
    collection do
      get 'search'
      get 'get_coordinators'
      post 'import'
      get 'download_template'
      post 'bulk_update'
    end
  end
end