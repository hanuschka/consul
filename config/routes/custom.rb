get "blobs/:key",            to: "blobs#show", as: :blob_asset
get "ckeditor/assets",      to: "ckeditor/assets#index"
get "ckeditor/assets/:key", to: "blobs#show"

namespace :ckeditor do
  resources :pictures, only: [:create, :update, :destroy] do
    get :custom_thumb_url, on: :member
  end
  resources :documents, only: [:create, :update, :destroy]
end

resources :user_resources, only: [:index]
get "/proposals/:proposal_id/dashboard/campaign", to: "dashboard#campaign", as: :proposal_dashbord_campaign

resources :proposal_notifications, only: [:new, :create, :show, :edit, :update, :destroy]

resources :unregistered_newsletter_subscribers, only: [:create]

controller :unregistered_newsletter_subscribers do
  scope path: "unregistered_newsletter_subscribers" do
    get "confirm_subscription/:confirmation_token",
      action: "confirm_subscription",
      as: :unregistered_newsletter_subscribers_confirm_subscription
    get "unsubscribe/:unsubscribe_token",
      action: "unsubscribe",
      as: :unregistered_newsletter_subscribers_unsubscribe
  end
end

get "users", to: "users#index"

resources :map_locations, only: [] do
  collection do
    get :get_coordinates
  end

  member do
    post :update_screenshot
  end
end

get "admin/matomo", to: "admin/matomo#index"
get "admin/connection", to: "admin/connection#index"

get "users", to: "users#index"

resources :projekt_point_of_interest_pins, only: [:new, :create] do
  member do
    get :json_data
  end
end


get "/:landing_page_slug/projekts", to: "projekts#index", as: :landing_page_projekts
get "/:landing_page_slug/projekts/:id", to: "pages#show", as: :landing_page_projekt_page
get "/:landing_page_slug/polls/:id", to: "polls#show", as: :landing_page_poll
get "/:landing_page_slug/proposals/:id", to: "proposals#show", as: :landing_page_proposal
get "/:landing_page_slug/budgets/:budget_id/investments/:id", to: "budgets/investments#show", as: :landing_page_budget_investment

post "iframe_sessions", to: "iframe_sessions#create"

post "/voice_assistant/create_session",               to: "voice_assistant#create_session"
get  "/voice_assistant/geocode_location_coordinates", to: "voice_assistant#geocode_location_coordinates"
post "/voice_assistant/generate_image",               to: "voice_assistant#generate_image"

resources :projekt_content_block_templates, only: [:index]
