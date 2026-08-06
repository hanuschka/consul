namespace :adm do
  root to: "home#show"

  patch "attribute/:record_type/:id", to: "attribute#update", as: :attribute

  # application
  resource :homepage, controller: "homepage", only: [:show] do
    patch :update_navigation_link_color, on: :collection
  end
  resource :navbar, controller: "navbar", only: [:show]
  resources :navbar_items, only: [:new, :create, :edit, :update, :destroy] do
    patch :reorder, on: :collection
  end
  resource :overview_pages, only: [], controller: "overview_pages" do
    get :projekt
    get :others
  end

  resources :settings, only: [] do
    get :metadata, on: :collection
    get :gdpr, on: :collection
    get :registration, on: :collection
    get :file_settings, on: :collection
  end
  resource :features, controller: "features", only: [:show]
  resource :whatsapp, controller: "whatsapp", only: [:show] do
    post :test_message
    post :create_template
    patch :use_template
    # PDF QR poster disabled for now — see Adm::WhatsappController.
    # get :qr_poster

    resources :dialogs, controller: "whatsapp_dialogs", only: [:show] do
      post :reply, on: :member
    end
  end
  resources :registered_addresses, only: [:index]
  resources :registered_address_streets, only: [] do
    get :search, on: :collection
  end
  resource :default_map_location, controller: "default_map_location", only: [:show, :update]
  resource :system_user, controller: "system_user", only: [:edit, :update]
  resources :map_locations, only: [] do
    post :update_screenshot, on: :member
  end
  resources :map_layers, only: [:new, :create, :edit, :update, :destroy]
  resources :saved_content_blocks, only: [:create, :update, :destroy]
  resources :tags, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :individual_groups, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    resources :individual_group_values, as: :values, only: [:show, :new, :create, :edit, :update, :destroy] do
      post :search_user, on: :member
      post :add_user, on: :member
      post :add_from_csv, on: :member
      delete :remove_user, on: :member
      delete :remove_email_from_auto_join_emails, on: :member
    end
  end
  resources :age_ranges, only: [:index, :new, :create, :edit, :update, :destroy] do
    patch :reorder, on: :collection
  end
  # application

  # profiles
  resource :role_assignment, only: [] do
    post :create
    delete :destroy
    post :create_pending
    delete :destroy_pending
  end

  resources :administrators, only: [:index, :new, :destroy] do
    post :search, on: :collection
  end
  resources :moderators, only: [:index, :new, :destroy] do
    post :search, on: :collection
  end
  resources :valuators, only: [:index, :new, :destroy] do
    post :search, on: :collection
  end
  resources :officing_managers, only: [:index, :new, :destroy] do
    post :search, on: :collection
  end
  resources :users, only: [:index, :edit, :update, :destroy] do
    patch :verify, on: :member
    patch :unverify, on: :member
    get :audits, on: :member
    get :csv_download, on: :collection
  end
  # profiles

  # notifications
  resources :modal_notifications, except: :show

  scope :newsletters do
    resources :recipient_groups, except: [:show, :new] do
      resources :filters,
                controller: "recipient_group_filters",
                only: [:create, :update, :destroy] do
        collection do
          post :reorder
          get :recount
        end
      end
    end
    resources :unregistered_newsletter_subscribers, only: [:index, :destroy]
  end
  resources :newsletters do
    member do
      post :deliver
      post :send_test
    end
    collection do
      get :settings
    end
    resources :content_blocks,
              controller: "newsletters/content_blocks",
              only: [:create, :update, :destroy] do
      member do
        patch :update_position
        patch :change_with_ai
        get :ai_generation_status
        delete :cancel_ai_generation
      end
      collection do
        post :generate_with_ai
      end
    end
  end
  # notifications

  resources :email_templates, only: [:update] do
    post :send_test, on: :member
  end
  resources :global_email_templates, only: [:index]

  resource :statistics, controller: "statistics", only: [:show]
  resource :matomo, controller: "matomo", only: [:show]
  resource :apps, controller: "apps", only: [:show]
  resource :connection, controller: "connection", only: [:show]
  get "connect", to: "connection#show"

  resources :ai_settings, only: [:index, :update] do
    patch :update_api_key, on: :collection
  end
  resources :external_api_keys, only: [:index, :show, :edit, :update]
  resources :api_clients, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    post :regenerate_token, on: :member
    get :logs, on: :member
    resource :service_user, only: [:edit, :update], controller: "api_clients/service_users"
  end
  resources :api_request_logs, only: [:index, :show] do
    delete :destroy_all, on: :collection
  end

  namespace :site_customization do
    resources :pages, only: [:index, :edit, :update] do
      patch :toggle_status, on: :member
      patch :reorder, on: :collection
    end

    resources :content_cards, only: [:edit, :update] do
      patch :toggle_active, on: :member
      patch :reorder, on: :collection
    end
  end

  resources :masterportal_imports, only: [:create] do
    collection do
      get :collections
      get :status
    end
  end

  # Redirects from the former projekts/overview_page and projekts/overviews routes
  get "projekts/overview_page/navigation", to: redirect("/adm/overview_pages/projekt")
  get "projekts/overview_page/footer",     to: redirect("/adm/overview_pages/projekt")
  get "projekts/overviews",                to: redirect("/adm/overview_pages/others")
end
