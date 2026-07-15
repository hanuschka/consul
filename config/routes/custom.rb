get "/evaluations/:token", to: "public/evaluations#show", as: :public_evaluation

delete "account/disconnect_identity", to: "account#disconnect_identity", as: :disconnect_identity_account

get "/map_data", to: "map_data#show", as: :map_data

post   "/ai/generate_image",                        to: "ai#generate_image",                        as: :ai_generate_image
post   "/ai/generate_image_and_assign_to_resource", to: "ai#generate_image_and_assign_to_resource", as: :ai_generate_image_and_assign_to_resource
delete "/ai/remove_image_from_resource",            to: "ai#remove_image_from_resource",            as: :ai_remove_image_from_resource

scope "proposals/generate", as: :generate_proposal do
  get   ":projekt_phase_id/new",   to: "proposals/generate#new_flow",       as: :new
  post  ":projekt_phase_id/draft", to: "proposals/generate#generate_draft", as: :draft
  get   ":id/edit_draft",   to: "proposals/generate#edit_draft",     as: :edit_draft
  patch ":id/update_draft", to: "proposals/generate#update_draft",   as: :update_draft
  get   ":id/evaluation",   to: "proposals/generate#evaluation",     as: :evaluation
  patch ":id/publish",      to: "proposals/generate#publish",        as: :publish
  get   ":id/success",      to: "proposals/generate#success",        as: :success
end

scope "budget_investments/generate", as: :generate_budget_investment do
  get   ":projekt_phase_id/new",   to: "budget_investments/generate#new_flow",       as: :new
  post  ":projekt_phase_id/draft", to: "budget_investments/generate#generate_draft", as: :draft
  get   ":id/edit_draft",   to: "budget_investments/generate#edit_draft",     as: :edit_draft
  patch ":id/update_draft", to: "budget_investments/generate#update_draft",   as: :update_draft
  get   ":id/evaluation",   to: "budget_investments/generate#evaluation",     as: :evaluation
  patch ":id/publish",      to: "budget_investments/generate#publish",        as: :publish
  get   ":id/success",      to: "budget_investments/generate#success",        as: :success
end

get "blobs/:key", to: "blobs#show", as: :blob_asset
get "blobs/:key/variant", to: "blobs#variant", as: :blob_variant
get "ckeditor/assets",      to: "ckeditor/assets#index"
get "ckeditor/assets/:key", to: "blobs#show"

namespace :ckeditor do
  resources :pictures, only: [:create, :update, :destroy] do
    get :custom_thumb_url, on: :member
  end
  resources :documents, only: [:create, :update, :destroy]
end

namespace :adm do
  namespace :files do
    resources :images, only: [:index, :show]
    resources :documents, only: [:index, :show, :update, :destroy] do
      get :documentable_type_filter, on: :collection
    end
  end

  namespace :maintenance do
    resources :resource_images, only: [:index, :show, :update, :destroy] do
      get :imageable_type_filter, on: :collection
    end
    resources :resource_documents, only: [:index, :show] do
      get :documentable_type_filter, on: :collection
    end
  end
end

namespace :file_manager do
  resources :images, only: [:index, :create, :show, :update, :destroy]
  resources :documents, only: [:index, :create, :show, :update, :destroy]
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
end

get "admin/connection", to: "admin/connection#index"

get "users", to: "users#index"

resources :projekt_point_of_interest_pins, only: [:new, :create] do
  member do
    get :json_data
  end
end

resources :masterportal_pins, only: [] do
  member do
    get :json_data
  end
end

resources :polls, only: [] do
  member do
    get :ai_analysis
  end
end

get "/:landing_page_slug/projekts", to: "projekts#index", as: :landing_page_projekts
get "/:landing_page_slug/events", to: "projekt_events#index", as: :landing_page_events
get "/:landing_page_slug/proposals", to: "proposals#index", as: :landing_page_proposals
get "/:landing_page_slug/polls", to: "polls#index", as: :landing_page_polls
get "/:landing_page_slug/investments", to: "investments#index", as: :landing_page_investments
get "/:landing_page_slug/projekts/:id",
  to: redirect("/%{id}")
get "/:landing_page_slug/polls/:id",
  to: redirect("/polls/%{id}")
get "/:landing_page_slug/proposals/:id",
  to: redirect("/proposals/%{id}")
get "/:landing_page_slug/budgets/:budget_id/investments/:id",
  to: redirect("/budgets/%{budget_id}/investments/%{id}")


post "/voice_assistant/create_session",               to: "voice_assistant#create_session"
post "/voice_assistant/create_session_v2",            to: "voice_assistant#create_session_v2"
get  "/voice_assistant/geocode_location_coordinates", to: "voice_assistant#geocode_location_coordinates"

get  "/voice_assistant_designs", to: "voice_assistant_designs#index", as: :voice_assistant_designs

resources :projekt_content_block_templates, only: [:index] do
  collection do
    get :metadata
  end
end

get "projekts_map_embed", to: "projekt_map_embeds#index", as: :projekts_map_embed
get "projekts/:projekt_id/map_embed", to: "projekt_map_embeds#show", as: :projekt_map_embed

post "session_keepalive/ping", to: "session_keepalive#ping", as: :session_keepalive_ping

namespace :api do
  namespace :masterportal do
    resources :category_icons, only: [:create]
  end
end
