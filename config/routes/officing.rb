namespace :officing do
  resources :polls, only: [:index] do
    get :final, on: :collection
    resources :results, only: [:new, :create, :index]

    resources :ballot_sheets, only: [:new, :create, :show, :index]
  end

  resource :booth, controller: "booth", only: [:new, :create]
  resource :residence, controller: "residence", only: [:new, :create]
  resources :voters, only: [:new, :create]

  namespace :offline_ballots do #custom
    get  ":budget_id/verify_user", action: :verify_user,           as: :verify_user
    post "find_or_create_user",    action: :find_or_create_user,   as: :find_or_create_user
    get  ":budget_id/investments", action: :investments,           as: :investments
  end

  namespace :offline_poll_voters do #custom
    get    ":poll_id/verify_user",                                   action: :verify_user,         as: :verify_user
    post   ":poll_id/find_or_create_user",                           action: :find_or_create_user, as: :find_or_create_user
    get    ":poll_id/questions",                                     action: :questions,           as: :questions
    post   ":poll_question_id/record_answer",                        action: :record_answer,       as: :record_answer
    delete ":poll_question_id/answer/:poll_answer_id/remove_answer", action: :remove_answer,       as: :remove_answer
  end

  root to: "dashboard#index"
end
