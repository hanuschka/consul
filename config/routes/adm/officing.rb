namespace :adm do
  scope :officing, module: :officing, as: :officing do
    root to: "home#show"

    resource :settings, only: [:show], controller: "settings" do
      get :contact_persons, on: :member
    end

    resources :contact_persons, controller: "/adm/section_contact_people",
              only: [:new, :create, :edit, :update, :destroy],
              path: "settings/contact_persons",
              defaults: { adm_section: "officing" } do
      post :search, on: :collection
    end

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

    resources :voting_phases, only: [] do
      member do
        get :verify_user
        post :do_verify_user
        get :officing_desk
      end

      resources :poll_answers, only: [:create, :destroy] do
        collection do
          post :update_open_answer
        end
      end
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
