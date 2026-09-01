namespace :adm do
  scope :deficiency_reports, module: :deficiency_reports, as: :deficiency_reports do
    root to: "home#show"
    get "list", to: "deficiency_reports#index", as: :deficiency_reports_list

    resources :officers, only: [:index, :create, :destroy] do
      post :search, on: :collection
      patch :toggle_manage_all, on: :member
    end

    resources :categories, only: [:index, :new, :create, :edit, :update, :destroy] do
      patch :order_categories, on: :collection

      resources :subcategories, only: [:index, :new, :create, :edit, :update, :destroy] do
        patch :order_subcategories, on: :collection
      end
    end

    resources :statuses, only: [:index, :new, :create, :edit, :update, :destroy] do
      patch :order_statuses, on: :collection
    end

    resources :intake_channels, only: [:index, :new, :create, :edit, :update, :destroy] do
      patch :order_intake_channels, on: :collection
    end

    resources :official_answer_templates, except: :show
    resources :officer_groups, except: :show
    resources :districts, only: [:index, :edit, :update]

    resources :areas, except: :show do
      post :order_areas, on: :collection
    end

    resources :email_templates, only: [:index] do
      get :settings, on: :collection
    end

    resource :stats, only: :show
    resource :ai_settings, only: [:show, :update]
    resource :settings, only: [:show], controller: "settings" do
      get :dashboard, on: :member
      get :contact_persons, on: :member
      get :naming, on: :member
    end

    resource :confirmation_popup, only: [:edit, :update]

    resources :contact_persons, controller: "/adm/section_contact_people",
              only: [:new, :create, :edit, :update, :destroy],
              path: "settings/contact_persons",
              defaults: { adm_section: "deficiency_reports" } do
      post :search, on: :collection
    end

    resources :deficiency_reports, only: [:new, :create, :show, :edit, :update, :destroy], path: "" do
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
        delete :remove_official_answer_document
        patch :toggle_watch
        get :unwatch
        post :share
      end
    end

    resources :memos, only: [:create, :destroy] do
      member do
        post :send_notification
      end
    end
  end
end
