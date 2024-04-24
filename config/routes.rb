Rails.application.routes.draw do
  mount Ckeditor::Engine => "/ckeditor"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  draw :account
  draw :admin
  draw :budget
  draw :comment
  draw :community
  draw :debate
  draw :devise
  draw :direct_upload
  draw :document
  draw :graphql
  draw :legislation
  draw :management
  draw :moderation
  draw :notification
  draw :officing
  draw :poll
  draw :proposal
  draw :related_content
  draw :sdg
  draw :sdg_management
  draw :tag
  draw :user
  draw :valuation
  draw :verification
  draw :projekt
  draw :projekt_management
  draw :deficiency_report_management
  draw :custom

  root "welcome#index"
  get "/welcome", to: "welcome#welcome"
  get "/consul.json", to: "installation#details"
  get "/code", to: redirect('users/sign_up/user_verification_code', status: 302)
  get "/latest_activity", to: "welcome#latest_activity" #custom

  resources :stats, only: [:index]
  resources :images, only: [:destroy]
  resources :documents, only: [:destroy]
  resources :follows, only: [:create, :destroy]
  resources :remote_translations, only: [:create]

  # Deficiency reports
  resources :deficiency_reports, only: [:index, :show, :new, :create, :destroy] do
    member do
      get     :json_data
      post    :vote
      patch   :update_status
      patch   :update_category
      patch   :update_officer
      patch   :notify_officer_about_new_comments
      patch   :update_official_answer
      patch   :approve_official_answer
      put     :flag
      put     :unflag
    end

    collection do
      get :suggest
    end
  end

  # More info pages
  get "help",                                              to: "pages#show", id: "help/index",             as: "help"
  get "help/how-to-use",                                   to: "pages#show", id: "help/how_to_use/index",  as: "how_to_use"
  get "help/faq",                                          to: "pages#show", id: "faq",                    as: "faq"

  # For intercepted internet explorer
  get "internet_explorer",                                 to: "pages#internet_explorer",                  as: "internet_explorer"

  # Static pages
  resources :pages, path: "/", only: [:show] do
    member do
      # get :comment_phase_footer_tab
      # get :debate_phase_footer_tab
      # get :proposal_phase_footer_tab
      # get :voting_phase_footer_tab
      # get :budget_phase_footer_tab
      # get :milestone_phase_footer_tab
      # get :projekt_notification_phase_footer_tab
      # get :newsfeed_phase_footer_tab
      # get :event_phase_footer_tab
      # get :argument_phase_footer_tab
      # get :livestream_phase_footer_tab
      # get :legislation_phase_footer_tab
      # get :question_phase_footer_tab
      get :extended_sidebar_map
    end
  end

  # Customize devise
  devise_scope :user do
    get    "users/sign_up/user_info",              to: "users/registrations#user_info",                    as: :collect_user_info
    post   "users/sign_up/user_info",              to: "users/registrations#create_user",                  as: :create_user
    get    "users/sign_up/user_location",          to: "users/registrations#user_location",                as: :collect_user_location
    patch  "users/sign_up/user_location",          to: "users/registrations#update_location",              as: :update_user_location
    get    "users/sign_up/user_details",           to: "users/registrations#user_details",                 as: :collect_user_details
    patch  "users/sign_up/user_details",           to: "users/registrations#update_details",               as: :update_user_details
    get    "users/sign_up/complete",               to: "users/registrations#complete",                     as: :complete_user_registration
    get    "users/sign_up/complete_code",          to: "users/registrations#complete_code",                as: :complete_user_registration_code
    get    "users/sign_up/user_verification_code", to: "users/registrations#user_verification_code",       as: :collect_user_verification_code
    patch  "users/sign_up/user_verification_code", to: "users/registrations#check_user_verification_code", as: :check_user_verification_code
  end

  # Post open answers
  post  "polls/questions/:id/answers/update_open_answer",   to: "polls/questions#update_open_answer", as: :update_open_answer

  # Managing bam verification code
  patch    "admin/users/:id/send_letter_verification_code",                  to: "admin/users#send_letter_verification_code",        as: :send_letter_verification_code
  patch    "admin/users/:id/cancel_letter_verification_code",                to: "admin/users#cancel_letter_verification_code",      as: :cancel_letter_verification_code

  # Confirm poll participation
  post "polls/:id/confirm_participation",                  to: "polls#confirm_participation",        as: :poll_confirm_participation

  # Toggle user generated images
  patch  "admin/proposals/:id/toggle_image",               to: "admin/proposals#toggle_image",       as: :admin_proposal_toggle_image
  patch  "admin/debates/:id/toggle_image",                 to: "admin/debates#toggle_image",         as: :admin_debate_toggle_image

  # Manuall verify user
  put "/admin/users/:id/verify",                           to: "admin/users#verify",                 as: :verify_admin_user
  put "/admin/users/:id/unverify",                         to: "admin/users#unverify",               as: :unverify_admin_user

  # unvote answer
  delete "/questions/:question_id/answers/:id",            to: "polls/answers#destroy",              as: :question_answer

  # poll stats and results scoped to question_answer
  get    "/polls/:poll_id/question_answers/:id/stats",     to: "polls/questions/answers#stats",      as: :stats_poll_question_answer
  get    "/polls/:poll_id/question_answers/:id/results",   to: "polls/questions/answers#results",    as: :results_poll_question_answer

  # csv details for poll questions
  get    "/polls/questions/:id/csv_answers_streets",       to: "polls/questions#csv_answers_streets", as: :polls_question_csv_answers_streets
  get    "/polls/questions/:id/csv_answers_votes",         to: "polls/questions#csv_answers_votes",   as: :polls_question_csv_answers_votes

  # csv details for poll results
  get    "/polls/:id/csv_answers_votes",                   to: "polls#csv_answers_votes",             as: :poll_csv_answers_votes

  # projekt page footer tabs
  get    "/:id/projekt_phase_footer_tab/:projekt_phase_id", to: "pages#projekt_phase_footer_tab",     as: :projekt_phase_footer_tab_page

  # projekt notifications
  post "/admin/projekt/:projekt_id/projekt_arguments/send_notifications",   to: "admin/projekt_arguments#send_notifications", as: :send_notifications_admin_projekt_projekt_arguments

  resources :formular_answers, only: %i[create update]

  get "/registered_addresses/find", to: "registered_addresses#find"
end
