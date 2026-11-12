namespace :adm do
  scope :offers, module: :offers, as: :offers do
    root to: "offers#index"

    resources :categories, except: :show do
      patch :order_categories, on: :collection
    end

    resource :settings, only: :show, controller: "settings"

    resources :offers, only: [:edit, :update, :destroy], path: ""
  end
end
