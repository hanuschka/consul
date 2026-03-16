namespace :adm do
  scope :landing_pages, module: :landing_pages, as: :landing_pages do
    root to: "landing_pages#index"

    resources :managers, only: [:index, :new, :edit, :update, :destroy] do
      post :search, on: :collection
      patch :toggle_manage_all_landing_pages, on: :member
    end

    resources :landing_pages, only: [:edit, :update], path: "" do
      patch :toggle_active, on: :member
      patch :reorder, on: :collection
    end
  end
end
