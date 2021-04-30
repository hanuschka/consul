require_dependency Rails.root.join("app", "controllers", "application_controller").to_s


class ApplicationController < ActionController::Base
  # http_basic_authenticate_with name: Rails.application.secrets.basic_auth_login, password: Rails.application.secrets.basic_auth_password

  private

  def all_selected_tags
    if params[:tags]
      params[:tags].split(",").map { |tag_name| Tag.find_by(name: tag_name) }.compact || []
    else
      []
    end
  end
end
