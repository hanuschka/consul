namespace :adm do
  scope :ideas, module: :ideas, as: :ideas do
    root to: "home#show"

    # Define specific resources first (matched before /:id)
    resources :officers, only: [:index, :create, :destroy] do
      post :search, on: :collection
      patch :toggle_manage_all, on: :member
    end

    resources :categories, only: [:index, :new, :create, :edit, :update, :destroy] do
      patch :order_categories, on: :collection
    end

    resources :districts, only: [:index, :edit, :update]
    resource :settings, only: [:show], controller: "settings" do
      get :dashboard, on: :member
      get :contact_persons, on: :member
    end

    resources :contact_persons, controller: "/adm/section_contact_people",
              only: [:new, :create, :edit, :update, :destroy],
              path: "settings/contact_persons",
              defaults: { adm_section: "ideas" } do
      post :search, on: :collection
    end

    resources :memos, only: [:create, :destroy] do
      member do
        post :send_notification
      end
    end

    # Ideas resource with path: "" (matched after specific resources)
    resources :ideas, only: [:show, :edit, :update, :destroy], path: "" do
      resources :audits, only: :show, controller: "idea_audits"
      resource :map_location, controller: "/adm/map_locations", only: [:update]
      member do
        get :administer
        get :audits
        patch :toggle_accepted
        patch :toggle_image
        patch :update_official_answer
      end
    end
  end
end
