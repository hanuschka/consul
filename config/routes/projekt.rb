resources :projekts, only: [:index, :show] do
  resources :projekt_questions, only: [:index, :show]
  resources :projekt_question_answers, only: [:create, :update]

  collection do
    get :footer_comments
  end

  member do
    get :json_data
    get :map_html
  end
end

post "update_selected_parent_projekt", to: "projekts#update_selected_parent_projekt"

get :events, to: "projekt_events#index", as: :projekt_events

resources :projekt_events, only: [] do
  resources :projekt_event_registrations, only: [:create, :destroy]
end

get "projekt_event_registrations/confirm/:token",
    to: "projekt_event_registrations#confirm",
    as: :confirm_projekt_event_registration

resources :projekt_livestreams, only: [:show] do
  member do
    post :new_questions
  end
end

resources :projekt_phases, only: [] do
  member do
    get :map_html
    post :toggle_subscription
    post :create_stat_question
    get :stat_question_status
    get :download_stat_answer
    delete :delete_stat_question
    get :download_all_stat_answers
  end
end

patch "/projekt_subscriptions/:id/toggle_subscription", to: "projekt_subscriptions#toggle_subscription", as: :toggle_subscription_projekt_subscription
