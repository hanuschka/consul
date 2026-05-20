namespace :adm do
  namespace :moderation do
    root to: "home#show"

    resource :settings, only: [:show], controller: "settings" do
      get :contact_persons, on: :member
    end

    resources :contact_persons, controller: "/adm/section_contact_people",
              only: [:new, :create, :edit, :update, :destroy],
              path: "settings/contact_persons",
              defaults: { adm_section: "moderation" } do
      post :search, on: :collection
    end

    resources :users, only: :index do
      member do
        put :hide
        put :block
      end
    end

    resources :proposals, only: :index do
      member do
        put :hide
        put :ignore_flag
      end
    end

    resources :budget_investments, only: :index do
      member do
        put :hide
        put :unhide
        put :ignore_flag
      end
    end

    resources :comments, only: :index do
      member do
        put :hide
        put :unhide
        put :ignore_flag
      end
    end
  end
end
