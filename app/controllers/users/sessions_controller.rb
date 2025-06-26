class Users::SessionsController < Devise::SessionsController
  def new
    store_location_for(:user, CGI::unescape(params[:intended_path])) if params[:intended_path].present?
    super
  end

  def destroy
    @stored_location = stored_location_for(:user)
    super
  end

  private

    def after_sign_out_path_for(resource)
      @stored_location.present? && !@stored_location.match("management") ? @stored_location : super
    end

    def verifying_via_email?
      return false if resource.blank?

      stored_path = session[stored_location_key_for(resource)] || ""
      stored_path[0..5] == "/email"
    end
end
