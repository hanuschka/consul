Rails.application.routes.draw do
  mount Ckeditor::Engine => "/ckeditor"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  draw :account
  draw :admin
  draw :annotation
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

  root "welcome#index"
  get "/welcome", to: "welcome#welcome"
  get "/consul.json", to: "installation#details"

  resources :stats, only: [:index]
  resources :images, only: [:destroy]
  resources :documents, only: [:destroy]
  resources :follows, only: [:create, :destroy]
  resources :remote_translations, only: [:create]

  # More info pages
  get "help",             to: "pages#show", id: "help/index",             as: "help"
  get "help/how-to-use",  to: "pages#show", id: "help/how_to_use/index",  as: "how_to_use"
  get "help/faq",         to: "pages#show", id: "faq",                    as: "faq"

  # Static pages
  resources :pages, path: "/", only: [:show]


  # Customize devise
  devise_scope :user do
    get    "users/sign_up/user_info",          to: "users/registrations#user_info",        as: :collect_user_info
    post   "users/sign_up/user_info",          to: "users/registrations#create_user",      as: :create_user
    get    "users/sign_up/user_location",      to: "users/registrations#user_location",    as: :collect_user_location
    patch  "users/sign_up/user_location",      to: "users/registrations#update_location",  as: :update_user_location
    get    "users/sign_up/user_details",       to: "users/registrations#user_details",     as: :collect_user_details
    patch  "users/sign_up/user_details",       to: "users/registrations#update_details",   as: :update_user_details
    get    "users/sign_up/complete",           to: "users/registrations#complete",         as: :complete_user_registration
  end


end
