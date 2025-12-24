namespace :adm do
  root to: "home#show"

  resources :projekts, only: [:index, :show]

  # application
  resource :homepage, controller: "homepage", only: [:show]
  resources :landing_pages do
    patch :toggle_active, on: :member
    patch :reorder, on: :collection
  end
  resources :documents, only: [:index, :new, :create, :destroy]
  resource :navbar, controller: "navbar", only: [:show]
  resources :navbar_items, only: [:new, :create, :destroy] do
    patch :reorder, on: :collection
  end

  resources :settings, only: [:update] do
    get :metadata, on: :collection
    get :gdpr, on: :collection
  end
  # application

  namespace :site_customization do
    resources :images, only: [:update]
    resources :content_cards, only: [:edit, :update] do
      patch :toggle_active, on: :member
      patch :reorder, on: :collection
    end
  end
end
