namespace :adm do
  scope :landing_pages, module: :landing_pages, as: :landing_pages do
    root to: "home#show"

    resources :managers, only: [:index, :new, :edit, :update, :destroy] do
      post :search, on: :collection
      patch :toggle_manage_all_landing_pages, on: :member
    end

    resource :settings, only: [:show], controller: "settings" do
      get :contact_persons, on: :member
    end

    resources :contact_persons, controller: "/adm/section_contact_people",
              only: [:new, :create, :edit, :update, :destroy],
              path: "settings/contact_persons",
              defaults: { adm_section: "landing_pages" } do
      post :search, on: :collection
    end

    resources :landing_pages, only: [:new, :create, :edit, :update, :destroy], path: "" do
      patch :toggle_active, on: :member
      patch :update_navigation_link_color, on: :member
      patch :reorder, on: :collection

      resources :navbar_items, only: [:new, :create, :edit, :update, :destroy],
        controller: "/adm/navbar_items" do
        patch :reorder, on: :collection
      end
    end
  end
end
