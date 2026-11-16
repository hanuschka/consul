namespace :adm do
  scope :offers, module: :offers, as: :offers do
    root to: "offers#index"

    resources :categories, except: :show do
      patch :order_categories, on: :collection
    end

    resources :providers, except: :show

    resource :settings, only: :show, controller: "settings"

    resources :offers, only: [:edit, :update, :destroy], path: "" do
      member do
        patch :mark_checked
        patch :hide
        patch :unhide
      end
    end
  end
end
