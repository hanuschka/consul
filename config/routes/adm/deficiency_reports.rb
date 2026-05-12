namespace :adm do
  scope :deficiency_reports, module: :deficiency_reports, as: :deficiency_reports do
    root to: "home#show"
    get "list", to: "deficiency_reports#index", as: :deficiency_reports_list

    resources :officers, only: [:index, :create, :destroy] do
      post :search, on: :collection
      patch :toggle_manage_all, on: :member
    end

    resources :categories, only: [:index, :new, :create, :edit, :update, :destroy] do
      post :order_categories, on: :collection
    end

    resources :statuses, only: [:index, :new, :create, :edit, :update, :destroy] do
      post :order_statuses, on: :collection
    end

    resources :official_answer_templates, except: :show
    resources :officer_groups, except: :show
    resources :districts, only: [:index, :edit, :update]

    resources :areas, except: :show do
      post :order_areas, on: :collection
    end

    resource :stats, only: :show
    resource :ai_settings, only: [:show, :update]
    get :settings, to: "deficiency_reports#settings", as: :settings
    get "settings/dashboard", to: "deficiency_reports#settings_dashboard", as: :settings_dashboard

    resources :deficiency_reports, only: [:show, :edit, :update, :destroy], path: "" do
      resources :audits, only: :show, controller: "deficiency_report_audits"
      resources :milestones, controller: "deficiency_report_milestones"
      resources :progress_bars, except: :show, controller: "deficiency_report_progress_bars"
      resource :map_location, controller: "/adm/map_locations", only: [:update]
      member do
        get :administer
        patch :update_administer
        get :audits
        get :feedback_form
        patch :accept
        patch :toggle_image
        patch :update_official_answer
      end
    end

    resources :memos, only: [:create, :destroy] do
      member do
        post :send_notification
      end
    end
  end
end
