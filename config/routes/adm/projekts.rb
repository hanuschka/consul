namespace :adm do
  scope :projekts, module: :projekts, as: :projekts do
    root to: "projekts#index"

    resources :managers, only: [:index, :new, :create, :destroy] do
      post :search, on: :collection
    end

    resources :phases, only: [:update] do
      resource :map_location, controller: "/adm/map_locations", only: [:update]
      resources :map_layers, controller: "/adm/map_layers", only: [:new, :create, :edit, :update, :destroy]
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

      resources :labels, except: %i[index show]
      resources :sentiments, except: %i[index show]
      resources :projekt_questions, except: %i[index show] do
        post :send_notifications, on: :collection
      end
      resources :projekt_point_of_interest_categories, except: %i[index show]
      resources :legislation_draft_versions, except: %i[index show]
      resources :proposals, only: [:show] do
        member do
          patch :toggle_admin_accepted
          patch :update_official_answer
        end
      end
    end

    resources :projekts, only: [:new, :create, :update, :destroy], path: "" do
      get :details, on: :member
      get :visibility, on: :member
      get :projekt_managers, on: :member
      get :map, on: :member
      get :phases, on: :member
      patch :toggle_activated, on: :member
      resource :map_location, controller: "/adm/map_locations", only: [:update]
      resources :map_layers, controller: "/adm/map_layers", only: [:new, :create, :edit, :update, :destroy]
      resources :phases, only: [:new, :create]
      resources :manager_assignments, only: [:update]
      patch :update_default_phase, on: :member
    end
  end
end
