  namespace :api do
    resources :projekts, shallow: true do
      member do
        patch :update_setting
        patch :update_page
        patch :update_image
      end

      resources :projekt_phases do
        member do
          patch :update_setting
        end
      end
      resources :content_blocks do
        collection do
          post :reorder
        end
      end
    end

    resources :projekt_phases, only: [], shallow: true do
      resources :proposals, controller: "proposals", only: [:index, :create, :show, :update, :destroy]
      resources :debates, only: [:create, :show, :update, :destroy]
      resources :polls, only: [:create, :show, :update, :destroy]
      resources :projekt_livestreams, only: [:create, :show, :update, :destroy]
      resources :projekt_questions, only: [:create, :show, :update, :destroy]
      resources :projekt_events, only: [:create, :show, :update, :destroy]
      resources :projekt_arguments, only: [:create, :show, :update, :destroy]
      resources :projekt_notifications, only: [:create, :show, :update, :destroy]
      resources :legislation_processes, only: [:create, :show, :update, :destroy]
      resources :projekt_point_of_interest_pins, only: [:create, :show, :update, :destroy]
      resources :projekt_point_of_interest_categories, only: [:create, :show, :update, :destroy]
    end
    # settings are updated via projekt_phases#update_setting

    resources :deficiency_reports, only: [:index, :show, :create, :update]
  end

  get "/api/docs", to: "docs#api"
  get "/api/docs_alt", to: "docs#api_alt"
