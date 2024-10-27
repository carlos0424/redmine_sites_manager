RedmineApp::Application.routes.draw do
  resources :sites do
    collection do
      get 'search'
      get 'get_coordinators'
      post 'import'
      get 'download_template'
      post 'bulk_update'
    end
    member do
      post 'toggle_status'
    end
  end
end