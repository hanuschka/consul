namespace :adm do
  scope :offers, module: :offers, as: :offers do
    root to: "offers#index"

    resources :categories, except: :show do
      patch :order_categories, on: :collection
    end

    resources :providers, except: :show

    resource :settings, only: :show, controller: "settings"

    resource :import, only: [:new, :create], controller: "imports" do
      get :template
      get :sample
    end

    resources :offers, only: [:edit, :update, :destroy], path: "" do
      member do
        patch :mark_checked
        patch :suspend
        patch :unsuspend
      end
    end
  end
end
