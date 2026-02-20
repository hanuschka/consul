namespace :adm do
  scope :ideas, module: :ideas, as: :ideas do
    root to: "ideas#index"

    # Define specific resources first (matched before /:id)
    resources :officers, only: [:index, :create, :destroy] do
      get :search, on: :collection
    end

    resources :categories, only: [:index, :new, :create, :edit, :update, :destroy] do
      post :order_categories, on: :collection
    end

    resources :settings, only: :index
    resources :districts, only: [:index, :edit, :update]

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
        patch :update_image
      end
    end
  end
end
