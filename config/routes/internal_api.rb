post "/connect_dt_service", to: "api_clients#connect", as: :connect_api_clients

namespace :internal_api do
  patch "/api_clients_registration/mark_as_registered"

  post "/auth/generate_frame_sign_in_token", to: "auth#generate_frame_sign_in_token"

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
    end

    collection do
      patch :update
    end
  end

  resources :images, only: [:create, :destroy]

  resources :apps, only: [:update]

  scope path: "settings" do
    patch "enable", to: "settings#enable"
    patch "disable", to: "settings#disable"
  end
end
