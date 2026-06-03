namespace :adm do
  scope :valuation, module: :valuation, as: :valuation do
    root to: "home#show"

    resource :settings, only: [:show], controller: "settings" do
      get :contact_persons, on: :member
    end

    resources :contact_persons, controller: "/adm/section_contact_people",
              only: [:new, :create, :edit, :update, :destroy],
              path: "settings/contact_persons",
              defaults: { adm_section: "valuation" } do
      post :search, on: :collection
    end

    resources :investments, only: [:edit, :update]
  end
end
