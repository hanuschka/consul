namespace :adm do
  scope :valuation, module: :valuation, as: :valuation do
    root to: "home#show"

    resources :investments, only: [:index, :edit, :update]
  end
end
