namespace :adm do
  scope :officing, module: :officing, as: :officing do
    root to: "dashboard#index"

    resources :budgets, only: [] do
      member do
        get :verify_user
        post :do_verify_user
        get :officing_desk
      end

      resources :ballot_lines, only: [:create, :destroy], controller: "budget_ballot_lines"
      resources :investment_votes, only: [:create, :destroy], controller: "budget_investment_votes"
    end
  end
end
