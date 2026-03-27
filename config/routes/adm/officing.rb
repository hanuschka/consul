namespace :adm do
  scope :officing, module: :officing, as: :officing do
    root to: "dashboard#index"

    resources :proposal_phases, only: [] do
      member do
        get :verify_user
        post :do_verify_user
        get :officing_desk
        get :bulk_votes
        post :update_bulk_votes
      end

      resources :proposal_votes, only: [:create, :destroy]
    end

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
