namespace :adm do
  root to: "home#show"

  patch "attribute/:record_type/:id", to: "attribute#update", as: :attribute, constraints: { record_type: %r{[^/]+(/[^/]+)?} }

  resources :projekts, only: [:index, :new, :create, :update, :destroy] do
    get :details, on: :member
    get :visibility, on: :member
    get :projekt_managers, on: :member
    get :map, on: :member
    patch :toggle_activated, on: :member
    resource :map_location, controller: "projekt_map_locations", only: [:update]
    resources :projekt_phases, controller: "projekt_phases", only: [:index, :new, :create, :update]
    patch :update_default_phase, on: :member
  end

  resources :projekt_phases, only: [:update] do
    member do
      # Phase configuration
      get :duration
      get :naming
      get :restrictions
      get :general_settings
      get :settings
      get :form_author
      get :user_functions

      # Content management
      get :proposals
      get :budget_phases
      get :budget_edit
      get :budget_investments
      get :poll_questions
      get :formular
      get :formular_answers
      get :milestones
      get :progress_bars
      get :legislation_process_draft_versions

      # Map & location
      get :map
      get :projekt_point_of_interest_categories
      get :projekt_point_of_interest_pins
      get :map_resources_overview

      # Labels & sentiments
      get :projekt_labels
      get :sentiments

      # Users & permissions
      get :officing_managers
      get :officing_manager_audits
      get :age_ranges_for_stats

      # AI
      get :ai_settings

      # Dynamic resources (from resources_name)
      get :projekt_notifications
      get :projekt_events
      get :projekt_livestreams
      get :projekt_questions
      get :projekt_arguments

      # Toggle actions
      patch :toggle_active
      patch :toggle_frontend_visibility
    end

    resources :projekt_labels, except: %i[index show]
    resources :sentiments, except: %i[index show]
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
  resources :registered_address_streets, only: [] do
    get :search, on: :collection
  end
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
