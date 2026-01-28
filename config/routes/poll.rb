resources :polls, only: [:show, :index] do
  member do
    get :stats
    get :results
    get :report
    get :evaluation
    post :refresh_ai_stats
    get :ai_stats_status
    get :download_report_section
    get :download_all_report_sections
  end

  resources :questions, controller: "polls/questions", shallow: true do
    post :answer, on: :member
    # resources :answers, controller: "polls/answers", only: :destroy, shallow: false
  end
end

resolve "Poll::Question" do |question, options|
  [:question, options.merge(id: question)]
end
