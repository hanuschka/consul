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

get "admin/matomo", to: "admin/matomo#index"

get "users", to: "users#index"
post "/connect_dt_service", to: "api_clients#connect", as: :connect_api_clients

namespace :api do
  patch "/api_clients_registration/mark_as_registered"

  post "/auth/generate_frame_sign_in_token", to: "auth#generate_frame_sign_in_token"
  # post "/auth/generate_temporary_auth_token", to: "auth#generate_temporary_auth_token"

  resources :projekts, only: [:index, :create, :update] do
    collection do
      get :overview
    end
    member do
      patch :update_page
      patch :import
    end
    patch "projekt_settings", to: "projekt_settings#update"

    resources :projekt_content_blocks, only: [:create]
  end

  resources :projekt_content_blocks, only: [:destroy, :update] do
    member do
      patch :update_position
    end
  end

  resources :projekt_phases do
    collection do
      post :reorder
    end
    member do
      post :send_notifications
      patch :set_as_default
    end

    collection do
      patch :update
    end
  end

  resources :images, only: [:create, :destroy]

  scope path: "settings" do
    patch "enable", to: "settings#enable"
    patch "disable", to: "settings#disable"
  end
end

post "iframe_sessions", to: "iframe_sessions#create"

# get "/admin/projekts/:projekt_id/frame_phases_restrictions", to: "admin/projekt_phases#frame_phases_restrictions", as: :admin_frame_phase_restrictons
get "/admin/projekts/:projekt_id/frame_new_phase_selector", to: "admin/projekt_phases#frame_new_phase_selector", as: :admin_frame_new_phase_selector
