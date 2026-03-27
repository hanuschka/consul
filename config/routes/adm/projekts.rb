namespace :adm do
  scope :projekts, module: :projekts, as: :projekts do
    root to: "projekts#index"

    resources :managers, only: [:index, :new, :create, :destroy] do
      post :search, on: :collection
      patch :toggle_manage_all_projekts, on: :member
    end

    resource :overview_page, only: [], controller: "overview_page" do
      get :navigation
      get :footer
    end

    resources :milestone_statuses, except: %i[show]

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
        get :comments
        get :proposal_criteria
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
        get :user_resource_criteria
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
        patch :update_age_ranges_for_stats
      end

      resources :labels, except: %i[index show]
      resources :sentiments, except: %i[index show]
      resources :projekt_questions, except: %i[index show] do
        post :send_notifications, on: :collection
      end
      resources :projekt_point_of_interest_categories, except: %i[index show]
      resources :milestones, controller: "milestones/phases", except: %i[index show]
      resources :progress_bars, controller: "progress_bars/phases", except: %i[index show]
      resources :legislation_draft_versions, except: %i[index show]
      resources :formular_fields, except: %i[index show]
      resources :projekt_events, except: %i[index show] do
        member do
          post :send_notifications
        end
      end
      resources :projekt_arguments, except: %i[index show] do
        post :send_notifications, on: :collection
      end
      resources :projekt_notifications, except: %i[index show]
      resources :projekt_livestreams, except: %i[index] do
        member do
          post :send_notifications
        end
      end
      resources :formular_follow_up_letters, only: [:create, :edit, :update, :destroy] do
        member do
          post :send_emails
        end
      end
      resources :proposals, only: [:show] do
        member do
          patch :toggle_admin_accepted
          patch :update_official_answer
          put :hide
          put :unhide
          put :ignore_flag
        end
      end
      resources :comments, only: [] do
        member do
          put :hide
          put :unhide
          put :ignore_flag
        end
      end
      resources :budget_phases, only: [:edit] do
        patch :toggle_enabled, on: :member
      end
      resources :budgets, only: [:update] do
        member do
          put :calculate_winners
          put :recalculate_winners
        end
      end
      resources :poll_questions, only: [:new, :create, :show, :edit, :update, :destroy] do
        patch :order_questions, on: :collection
        resources :poll_question_answers, only: [:new, :create, :edit, :update, :destroy] do
          patch :order_answers, on: :collection
        end
      end
      resources :budget_investments, only: [:show, :edit, :update, :destroy] do
        resource :map_location, controller: "/adm/map_locations", only: [:update]
        resources :milestones, controller: "milestones/budget_investments", except: %i[index show]
        resources :progress_bars, controller: "progress_bars/budget_investments", except: %i[index show]
        member do
          get :administer
          get :people
          patch :frame_update
          get :milestones
          get :progress_bars
          get :audits
          put :hide
          put :unhide
          put :ignore_flag
        end
      end
    end

    resources :projekts, only: [:new, :create, :update, :destroy], path: "" do
      collection do
        get :import_projekt
      end
      member do
        get :details
        get :visibility
        get :projekt_managers
        get :map
        get :phases
        patch :toggle_activated
        patch :update_default_phase
      end
      resource :map_location, controller: "/adm/map_locations", only: [:update]
      resources :map_layers, controller: "/adm/map_layers", only: [:new, :create, :edit, :update, :destroy]
      resources :phases, only: [:new, :create]
      resources :manager_assignments, only: [:update]
    end
  end
end
