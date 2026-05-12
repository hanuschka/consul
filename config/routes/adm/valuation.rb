namespace :adm do
  scope :valuation, module: :valuation, as: :valuation do
    root to: "home#show"

    resource :settings, only: [:show], controller: "settings"

    resources :investments, only: [:index, :edit, :update]
  end
end
