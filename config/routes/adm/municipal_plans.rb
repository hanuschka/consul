namespace :adm do
  scope :municipal_plans, module: :municipal_plans, as: :municipal_plans do
    root to: "home#show"
    get "list", to: "municipal_plans#index", as: :municipal_plans_list

    resources :officers, only: [:index, :create, :destroy] do
      post :search, on: :collection
    end

    resources :officer_groups, except: :show

    resources :topics, except: :show do
      patch :order_topics, on: :collection
    end

    resource :settings, only: :show, controller: "settings" do
      get :dashboard, on: :member
      get :contact_persons, on: :member
    end

    resources :contact_persons, controller: "/adm/section_contact_people",
              only: [:new, :create, :edit, :update, :destroy],
              path: "settings/contact_persons",
              defaults: { adm_section: "municipal_plans" } do
      post :search, on: :collection
    end

    resources :memos, only: [:create, :destroy] do
      member do
        post :send_notification
      end
    end

    resources :municipal_plans, only: [:new, :create, :show, :edit, :update, :destroy], path: "" do
      collection do
        get :order
        patch :reorder
      end

      member do
        patch :submit
        patch :release
        patch :archive
        patch :unarchive
        patch :archive_date
        get :audits
      end

      resources :audits, only: :show, controller: "municipal_plan_audits"
      resources :notices, only: :destroy, controller: "municipal_plan_notices"
      resource :projekt_conversion, only: [:new, :create]
    end
  end
end
