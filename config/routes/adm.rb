namespace :adm do
  root to: "home#show"

  patch "attribute/:record_type/:id", to: "attribute#update", as: :attribute, constraints: { record_type: %r{[^/]+(/[^/]+)?} }

  # application
  resource :homepage, controller: "homepage", only: [:show]
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
  resources :officing_managers, only: [:index, :new, :destroy] do
    post :search, on: :collection
  end
  resources :users, only: [:index, :edit, :update] do
    patch :verify, on: :member
    patch :unverify, on: :member
    get :csv_download, on: :collection
  end
  # profiles

  # notifications
  resources :modal_notifications, except: :show

  scope :newsletters do
    resources :recipient_groups, except: :show do
      collection do
        post :select_options
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
  end
  # notifications

  resources :email_templates, only: [:update] do
    post :send_test, on: :member
  end
  resources :global_email_templates, only: [:index]

  resource :statistics, controller: "statistics", only: [:show]
  resource :apps, controller: "apps", only: [:show]

  resources :ai_settings, only: [:index, :update] do
    patch :update_api_key, on: :collection
  end
  resources :external_api_keys, only: [:index, :show, :edit, :update]
  resources :api_clients, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    post :regenerate_token, on: :member
  end
  resources :api_request_logs, only: [:index, :show]

  namespace :site_customization do
    get "pages/:slug/edit", to: "pages#edit", as: :edit_page_by_slug

    resources :content_cards, only: [:edit, :update] do
      patch :toggle_active, on: :member
      patch :reorder, on: :collection
    end
  end
end
