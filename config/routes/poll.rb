resources :polls, only: [:show, :index] do
  member do
    get :stats
    get :results
    get :evaluation
    get :report
    post :refresh_ai_stats
    get :ai_stats_status
  end

  resources :questions, controller: "polls/questions", shallow: true do
    post :answer, on: :member
    # resources :answers, controller: "polls/answers", only: :destroy, shallow: false
  end
end

resolve "Poll::Question" do |question, options|
  [:question, options.merge(id: question)]
end
