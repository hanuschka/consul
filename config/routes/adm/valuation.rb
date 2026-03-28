namespace :adm do
  scope :valuation, module: :valuation, as: :valuation do
    root to: "investments#index"

    resources :investments, only: [:index, :edit, :update]
  end
end
