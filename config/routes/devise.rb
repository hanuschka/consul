devise_for :users, controllers: {
                     registrations: "users/registrations",
                     sessions: "users/sessions",
                     passwords: "users/passwords",
                     confirmations: "users/confirmations",
                     omniauth_callbacks: "users/omniauth_callbacks"
                   }

devise_scope :user do
  patch "/user/confirmation", to: "users/confirmations#update", as: :update_user_confirmation
  get "/user/registrations/check_username", to: "users/registrations#check_username"
  get "users/sign_up/success", to: "users/registrations#success"
  get "users/registrations/delete_form", to: "users/registrations#delete_form"
  delete "users/registrations", to: "users/registrations#delete"
  get :finish_signup, to: "users/registrations#finish_signup"
  patch :do_finish_signup, to: "users/registrations#do_finish_signup"

  get "users/registrations/update_registered_address_street_field",
    to: "users/registrations#update_registered_address_street_field" # custom line
  get "users/registrations/update_registered_address_field",
    to: "users/registrations#update_registered_address_field" # custom line

  get "users/registrations/sign_in_guest", to: "users/registrations#sign_in_guest", as: :new_guest_user_registration # custom line
  post "users/registrations/create_guest", to: "users/registrations#create_guest" # custom line
  delete "users/registrations/sign_out_guest", to: "users/registrations#sign_out_guest", as: :destroy_guest_user_session # custom line

  #BundID
  get  "users/send_bund_id_request",  to: "users/omniauth_callbacks#send_bund_id_request",      as: :users_bund_id_send_request
  post "sp/SAML2/POST",               to: "users/omniauth_callbacks#process_bund_id_response",  as: :users_bund_id_process_response
end

devise_for :organizations, class_name: "User",
           controllers: {
             registrations: "organizations/registrations",
             sessions: "devise/sessions"
           },
           skip: [:omniauth_callbacks]

devise_scope :organization do
  get "organizations/sign_up/success", to: "organizations/registrations#success"
end
