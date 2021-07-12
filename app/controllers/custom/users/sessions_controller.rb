require_dependency Rails.root.join("app", "controllers", "users", "sessions_controller").to_s

class Users::SessionsController < Devise::SessionsController
  http_basic_authenticate_with name: Rails.application.secrets.http_basic_username, password:  Rails.application.secrets.http_basic_password
end
