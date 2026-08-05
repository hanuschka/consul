post "/connect_dt_service", to: "internal_api_clients#connect", as: :connect_api_clients

namespace :internal_api do
  patch "/internal_api_clients_registration/mark_as_registered"

  resources :projekts, only: [:index, :create, :update] do
    collection do
      get :overview
    end
    member do
      patch :update_page
      patch :update_title_image
      patch :import
      patch :update_managers_list
    end
    patch "projekt_settings", to: "projekt_settings#update"

    resources :projekt_content_blocks, only: [:create]
  end

  resources :users, only: [] do
    member do
      patch :mark_as_on_dt
    end
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
      patch :update_setting
    end

    collection do
      patch :update
    end
  end

  get "projekt_import_references", to: "projekt_import_references#show"

  resources :images, only: [:create, :destroy]

  resources :api_request_logs, only: [] do
    collection do
      delete :destroy_bad
    end
  end

  resources :apps, only: [:update]

  scope path: "settings" do
    patch "enable", to: "settings#enable"
    patch "disable", to: "settings#disable"
  end

  get "dashboard/api_works", to: "dashboard#api_works"

  get "connection/dt_status", to: "connection#dt_status"

  get "connection/update_client_info", to: "connection#update_client_info"

  patch "connection/sync_client_domain", to: "connection#sync_client_domain"

  get "stats", to: "stats#show"

  get "ai_features", to: "ai_features#show"
end
