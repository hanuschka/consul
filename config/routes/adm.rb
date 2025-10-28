namespace :adm do
  root to: "home#show"

  resources :projekts, only: [:index, :show]

  # application
  resource :homepage, controller: "homepage", only: [:show]
  resources :landing_pages, only: [:index]
  resources :documents, only: [:index]
  resource :navbar, controller: "navbar", only: [:show]

  resources :settings, only: [:update] do
    get :metadata, on: :collection
    get :gdpr, on: :collection
  end
end
