namespace :adm do
  scope :projekts, module: :projekts, as: :projekts do
    root to: "home#show"
    get "list", to: "projekts#list", as: :projekts_list

    resources :managers, only: [:index, :new, :create, :destroy] do
      post :search, on: :collection
      patch :toggle_manage_all_projekts, on: :member
    end

    resource :settings, only: [:show], controller: "settings" do
      get :contact_persons, on: :member
    end

    resource :inspiration, only: [:show], controller: "inspiration"

    resources :contact_persons, controller: "/adm/section_contact_people",
              only: [:new, :create, :edit, :update, :destroy],
              path: "settings/contact_persons",
              defaults: { adm_section: "projekts" } do
      post :search, on: :collection
    end

    resources :milestone_statuses, except: %i[show]

    resources :projekt_settings, only: [:update]

    resources :phases, only: [:update, :destroy] do
      resource :map_location, controller: "/adm/map_locations", only: [:update]
      resources :map_layers, controller: "/adm/map_layers", only: [:new, :create, :edit, :update, :destroy]

      member do
        get :email_templates
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
        patch :go_live
        get :formular
        get :formular_answers
        get :formular_follow_up_emails

        # Mitmachbox
        get :mitmachbox_survey
        post :mitmachbox_create_survey
        patch :mitmachbox_survey_state
        post :mitmachbox_create_draft
        post :mitmachbox_publish_draft
        get :mitmachbox_deployments
        get :mitmachbox_results
        get :mitmachbox_results_export
        get :milestones
        get :progress_bars
        get :legislation_process_draft_versions

        # Map & location
        get :map
        get :masterportal_pins
        get :masterportal_pins_summary
        delete :destroy_all_masterportal_pins
        get :destroy_all_masterportal_pins_status
        delete "masterportal_pins/:masterportal_pin_id" => "phases#destroy_masterportal_pin",
               as: :destroy_masterportal_pin
        patch "masterportal_collections/:masterportal_collection_id" =>
              "phases#update_masterportal_collection", as: :update_masterportal_collection
        patch "masterportal_collections/:masterportal_collection_id/color" =>
              "phases#update_masterportal_collection_color",
              as: :update_masterportal_collection_color
        delete "masterportal_collections/:masterportal_collection_id" =>
               "phases#destroy_masterportal_collection", as: :destroy_masterportal_collection
        get "masterportal_collections/:masterportal_collection_id/status" =>
            "phases#masterportal_collection_status", as: :masterportal_collection_status
        get "masterportal_collections/:masterportal_collection_id/diff" =>
            "phases#masterportal_collection_diff", as: :masterportal_collection_diff
        get "masterportal_collections/:masterportal_collection_id/card" =>
            "phases#masterportal_collection_card", as: :masterportal_collection_card
        delete "masterportal_collections/:masterportal_collection_id/stale_pins" =>
               "phases#clean_masterportal_collection_stale_pins",
               as: :clean_masterportal_collection_stale_pins
        get :projekt_point_of_interest_categories
        get :projekt_point_of_interest_pins
        delete "projekt_point_of_interest_pins/:pin_id" => "phases#destroy_projekt_point_of_interest_pin",
               as: :destroy_projekt_point_of_interest_pin
        get :map_resources_overview

        # Labels & sentiments
        get :projekt_labels
        get :sentiments

        # Users & permissions
        get :ai_user_flow
        post :create_user_resource_criterion
        patch :update_user_resource_criterion
        delete :destroy_user_resource_criterion
        patch :reorder_user_resource_criteria
        get :officing_managers
        get :officing_manager_audits
        get :age_ranges_for_stats

        # AI
        get :ai_settings
        patch :update_ai_settings

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

        # Notifications
        post :send_notifications
      end

      resources :labels, except: %i[index show]
      resources :sentiments, except: %i[index show]
      resources :projekt_questions, except: %i[index show] do
        post :send_notifications, on: :collection
      end
      resources :projekt_point_of_interest_categories, except: %i[index show]
      resources :milestones, controller: "milestones/phases", except: %i[index show]
      resources :progress_bars, controller: "progress_bars/phases", except: %i[index show]
      resources :legislation_draft_versions, except: %i[index show] do
        get :draft_text, on: :member
      end
      resources :formular_fields, except: %i[index show] do
        collection do
          patch :reorder
        end
      end
      resources :mitmachbox_questions, only: %i[new create edit update destroy] do
        member do
          patch :move_up
          patch :move_down
        end
        resources :mitmachbox_options, only: %i[new create edit update destroy]
      end
      resources :mitmachbox_deployments, only: %i[new create edit update destroy]
      resources :projekt_events, except: %i[index] do
        member do
          post :send_notifications
        end
        resources :registrations, only: %i[index destroy], controller: "projekt_event_registrations" do
          member do
            post :resend_confirmation
          end
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
      resources :stat_questions, only: [] do
        member do
          get :poll
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
          patch :toggle_image_concealed
        end
      end
    end

    resources :memos, only: [:create, :destroy] do
      member do
        post :send_notification
      end
    end

    resources :imports, only: [:index, :new, :create, :show, :destroy],
              controller: "imports/from_files",
              defaults: { adm_section: "projekts" } do
      member do
        get :status
        post :reset
      end

      resource :chat, only: [:show], controller: "imports/chats" do
        get :messages
        get :summary
        post :message
        post :command
        post :extract
        post :execute
        post :title_image
      end
    end

    resources :projekts, only: [:new, :create, :update, :destroy], path: "" do
      get :details, on: :member
      get :visibility, on: :member
      get :projekt_managers, on: :member
      get :map, on: :member
      get :phases, on: :member
      get :images, on: :member
      get :documents, on: :member
      get :evaluation, on: :member
      get :report_summary, on: :member
      get "evaluation/:phase_id", on: :member, action: :evaluation_phase,
          as: :evaluation_phase, constraints: { phase_id: /\d+/ }
      get :poll_answer_participation, on: :member
      get :poll_answer_crossectional, on: :member
      get :evaluation_visibility, on: :member
      patch :update_evaluation_visibility, on: :member
      patch :toggle_evaluation_section_visibility, on: :member
      patch :toggle_evaluation_tab_visibility, on: :member
      post :generate_evaluation, on: :member
      get :evaluation_status, on: :member
      post :regenerate_phase_evaluation, on: :member
      post :regenerate_phase_regular_stats, on: :member
      post :regenerate_phase_ai_stats, on: :member
      get :phase_evaluation_status, on: :member
      get :evaluation_pdf_options, on: :member
      get :evaluation_pdf, on: :member
      post :copy, on: :member
      get :copy_status, on: :member
      patch :toggle_activated, on: :member
      post :notify_reviewers, on: :member
      patch :toggle_hide_content_background, on: :member
      patch :update_color, on: :member
      patch :update_taxonomy, on: :member
      patch :convert_to_new_content_block_mode, on: :member
      patch :update_default_phase, on: :member
      patch :update_image, on: :member
      delete :delete_image, on: :member
      post :generate_image, on: :member
      get :generate_image_status, on: :member
      resource :map_location, controller: "/adm/map_locations", only: [:update]
      resources :map_layers, controller: "/adm/map_layers", only: [:new, :create, :edit, :update, :destroy]
      resources :phases, only: [:new, :create] do
        patch :reorder, on: :collection
      end
      resources :manager_assignments, only: [:update]
    end
  end
end
