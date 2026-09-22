namespace :adm do
  scope :municipal_plans, module: :municipal_plans, as: :municipal_plans do
    root to: "municipal_plans#index"

    resources :officers, only: [:index, :create, :destroy] do
      post :search, on: :collection
    end

    resources :officer_groups, except: :show

    resources :topics, except: :show do
      patch :order_topics, on: :collection
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
      end

      resources :audits, only: :show, controller: "municipal_plan_audits"
      resources :notices, only: :destroy, controller: "municipal_plan_notices"
    end
  end
end
