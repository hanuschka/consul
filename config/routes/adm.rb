namespace :adm do
  root to: "home#show"

  patch "attribute/:record_type/:id", to: "attribute#update", as: :attribute, constraints: { record_type: %r{[^/]+(/[^/]+)?} }

  resources :projekts, only: [:index, :update, :destroy] do
    get :details, on: :member
    get :visibility, on: :member
    get :projekt_managers, on: :member
    get :map, on: :member
    patch :toggle_activated, on: :member
    resource :map_location, controller: "projekt_map_locations", only: [:update]
  end

  resources :projekt_manager_assignments, only: [:update]

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

  resources :settings, only: [] do
    get :metadata, on: :collection
    get :gdpr, on: :collection
    get :registration, on: :collection
  end
  resources :registered_addresses, only: [:index]
  resource :default_map_location, controller: "default_map_location", only: [:show, :update]
  resources :map_layers, only: [:new, :create, :edit, :update, :destroy]
  resources :tags, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :individual_groups, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :age_ranges, only: [:index, :new, :create, :edit, :update, :destroy] do
    patch :reorder, on: :collection
  end
  # application

  # profiles
  resource :role_assignment, only: [] do
    post :create
    delete :destroy
  end

  resources :administrators, only: [:index, :new, :destroy] do
    post :search, on: :collection
  end
  resources :projekt_managers, only: [:index, :new, :destroy] do
    post :search, on: :collection
  end
  resources :deficiency_report_managers, only: [:index, :new, :destroy] do
    post :search, on: :collection
  end
  resources :deficiency_report_officers, only: [:index, :new, :create, :destroy] do
    post :search, on: :collection
  end
  resources :idea_managers, only: [:index, :new, :destroy] do
    post :search, on: :collection
  end
  resources :moderators, only: [:index, :new, :destroy] do
    post :search, on: :collection
  end
  resources :valuators, only: [:index, :new, :destroy] do
    post :search, on: :collection
  end
  resources :users, only: [:index, :edit, :update] do
    patch :verify, on: :member
    patch :unverify, on: :member
  end
  # profiles

  namespace :site_customization do
    resources :content_cards, only: [:edit, :update] do
      patch :toggle_active, on: :member
      patch :reorder, on: :collection
    end
  end
end
