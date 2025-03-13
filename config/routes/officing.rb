namespace :officing do
  resources :polls, only: [:index] do
    get :final, on: :collection
    resources :results, only: [:new, :create, :index]

    resources :ballot_sheets, only: [:new, :create, :show, :index]
  end

  resource :booth, controller: "booth", only: [:new, :create]
  resource :residence, controller: "residence", only: [:new, :create]
  resources :voters, only: [:new, :create]

  # custom

  resources :polls, only: [] do
    member do
      get    :verify_user
      post   :find_or_create_user
      get    :officing_desk
      post   "/poll_questions/:poll_question_id/record_answer",                              action: :record_answer,       as: :record_answer
      patch  "/poll_questions/:poll_question_id/answers/:poll_answer_id/update_open_answer", action: :update_open_answer,  as: :update_open_answer
      delete "/poll_questions/:poll_question_id/answers/:poll_answer_id/remove_answer",      action: :remove_answer,       as: :remove_answer
    end
  end

  resources :budgets, only: [] do
    member do
      get    :verify_user
      post   :find_or_create_user
      get    :officing_desk
    end
  end

  resources :proposal_phases, only: [] do
    member do
      get    :verify_user
      post   :find_or_create_user
      get    :officing_desk
      get    :bulk_votes
      post   :update_bulk_votes
    end
  end

  root to: "dashboard#index"
end
