  get "/api/docs", to: "docs#api"
  get "/api/docs_alt", to: "docs#api_alt"

  namespace :api do
    namespace :auth do
      post :rotate_token, to: "rotate_token#create"
    end

    resources :projekts, shallow: true do
      member do
        patch :update_setting
        patch :update_settings
        patch :update_page
        patch :update_page_image
        patch :update_body
      end

      resources :projekt_phases do
        member do
          patch :update_setting
          patch :update_settings
        end
      end
    end

    resources :projekt_phases, only: [], shallow: true do
      resources :proposals, controller: "proposals", only: [:index, :create, :show, :update, :destroy] do
        member do
          patch :update_image
          patch :publish
        end
      end
      resources :debates, only: [:create, :show, :update, :destroy]
      resources :polls, only: [:index, :create, :show, :update, :destroy]
      resources :livestreams, only: [:index, :create, :show, :update, :destroy] do
        resources :questions, only: [:create]
      end
      resources :questions, only: [:index, :create, :show, :update, :destroy], shallow: true do
        resources :question_options, only: [:create, :show, :update, :destroy]
      end
      resources :events, only: [:index, :create, :show, :update, :destroy]
      resources :arguments, only: [:index, :create, :show, :update, :destroy]
      resources :notifications, only: [:index, :create, :show, :update, :destroy]
      resources :texts, only: [:index]
      resources :point_of_interest_pins, only: [:index, :create, :show, :update, :destroy]
      resources :point_of_interest_categories, only: [:index, :create, :show, :update, :destroy]
      resources :comments, only: [:index, :create, :show, :destroy]
      resources :budgets, only: [:index, :create, :show, :update, :destroy]
      resources :formulars, only: [:index, :create, :show, :update, :destroy]
      resources :milestones, only: [:index, :create]
      resources :progress_bars, only: [:index, :create, :show, :update, :destroy]

      resource :iframe, only: [:show, :update]
    end
    # settings are updated via projekt_phases#update_setting

    resources :deficiency_reports, only: [:index, :show, :create, :update]
    resources :deficiency_report_categories, only: [:index]
    resources :ideas, only: [:index, :show, :create, :update]
    resources :idea_categories, only: [:index, :show, :create, :update, :destroy]
    resources :idea_officers, only: [:index]
    resources :polls, only: [:index, :show] do
      resources :poll_questions, only: [:index, :create], path: "questions", as: :questions
    end
    resources :poll_questions, only: [:show, :update, :destroy] do
      resources :poll_question_answers, only: [:index, :create], path: "answers", as: :answers
      patch :order_answers, to: "poll_question_answers#order_answers", path: "answers/order"
    end
    resources :poll_question_answers, only: [:show, :update, :destroy]
    resources :livestreams, only: [:index, :show]
    resources :proposals, only: [:index, :show]
    resources :events, only: [:index, :show]
    resources :notifications, only: [:index, :show]
    resources :questions, only: [:index, :show]
    resources :comments, only: [:index, :show]
    resources :point_of_interest_pins, only: [:index, :show]
    resources :point_of_interest_categories, only: [:index, :show]
    resources :milestone_statuses, only: [:index, :create, :show, :update, :destroy]
    resources :budgets, only: [:index, :show], shallow: true do
      resources :investments, controller: "budgets/investments", only: [:index, :show, :create, :update, :destroy]
      resources :budget_phases, controller: "budgets/phases", only: [:index, :show, :update] do
        collection do
          patch :bulk_update
        end
      end
    end
    resources :budget_investments, only: [:index, :show], controller: "budgets/investments"

    namespace :masterportal do
      resources :category_icons, only: [:create]
    end

    match '*path', to: 'not_found#index', via: [:get, :post, :patch, :put, :delete]
  end
