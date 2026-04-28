namespace :adm do
  scope :landing_pages, module: :landing_pages, as: :landing_pages do
    root to: "home#show"
    get "list", to: "landing_pages#index", as: :landing_pages_list

    resources :managers, only: [:index, :new, :edit, :update, :destroy] do
      post :search, on: :collection
      patch :toggle_manage_all_landing_pages, on: :member
    end

    resources :landing_pages, only: [:new, :create, :edit, :update], path: "" do
      patch :toggle_active, on: :member
      patch :reorder, on: :collection

      resources :navbar_items, only: [:new, :create, :edit, :update, :destroy],
        controller: "/adm/navbar_items" do
        patch :reorder, on: :collection
      end
    end
  end
end
