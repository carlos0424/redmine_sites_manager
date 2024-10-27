# Plugin's routes
RedmineApp::Application.routes.draw do
  resources :sites do
    collection do
      get 'search'
      post 'import'
      post 'toggle_status'
      post 'clear'
    end
  end
end
