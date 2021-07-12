require_dependency Rails.root.join("app", "controllers", "users", "registrations_controller").to_s

class Users::RegistrationsController < Devise::RegistrationsController
  http_basic_authenticate_with name: Rails.application.secrets.http_basic_username, password:  Rails.application.secrets.http_basic_password
end
