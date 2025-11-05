  namespace :api do
    resources :projekts, shallow: true do
      member do
        patch :update_setting
        patch :update_page
        patch :update_image
        patch :update_body
      end

      resources :projekt_phases do
        member do
          patch :update_setting
        end
      end
    end

    resources :projekt_phases, only: [], shallow: true do
      resources :proposals, controller: "proposals", only: [:index, :create, :show, :update, :destroy] do
        member do
          patch :update_image
        end
      end
      resources :debates, only: [:create, :show, :update, :destroy]
      resources :polls, only: [:create, :show, :update, :destroy]
      resources :livestreams, only: [:create, :show, :update, :destroy]
      resources :questions, only: [:create, :show, :update, :destroy]
      resources :events, only: [:create, :show, :update, :destroy]
      resources :arguments, only: [:create, :show, :update, :destroy]
      resources :notifications, only: [:create, :show, :update, :destroy]
      resources :texts, only: [:create, :show, :update, :destroy]
      resources :point_of_interest_pins, only: [:create, :show, :update, :destroy]
      resources :point_of_interest_categories, only: [:create, :show, :update, :destroy]
      resources :comments, only: [:index, :create, :show]
      resources :budgets, only: [:create, :show, :update, :destroy]
      resources :formulars, only: [:create, :show, :update, :destroy]
      resources :milestones, only: [:index, :create, :show, :update, :destroy]
      resources :iframes, only: [:show, :update]
    end
    # settings are updated via projekt_phases#update_setting

    resources :deficiency_reports, only: [:index, :show, :create, :update]
    resources :ideas, only: [:index, :show, :create, :update]
    resources :budgets, only: [:show] do
      resources :investments, controller: "budgets/investments", only: [:index, :show, :create, :update]
    end
  end

  get "/api/docs", to: "docs#api"
  get "/api/docs_alt", to: "docs#api_alt"
