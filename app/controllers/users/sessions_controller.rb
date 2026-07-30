class Users::SessionsController < Devise::SessionsController
  def new
    store_location_for(:user, CGI::unescape(params[:intended_path])) if params[:intended_path].present?
    super
  end

  def destroy
    @stored_location = stored_location_for(:user)
    @kobil_single_logout_url = kobil_single_logout_url

    super
  end

  private

    def after_sign_out_path_for(resource)
      return @kobil_single_logout_url if @kobil_single_logout_url.present?

      @stored_location.present? && !@stored_location.match("management") ? @stored_location : super
    end

    def kobil_single_logout_url
      return if Setting["feature.kobil_single_logout"].blank?
      return if current_user.blank?
      return if current_user.identities.where(provider: "kobil").none?

      issuer = Kobil::Settings.credential(:issuer)
      return if issuer.blank?

      query = {
        client_id: Kobil::Settings.credential(:client_id)
        # post_logout_redirect_uri: Kobil::Settings.credential(:post_logout_redirect_uri)
      }.compact

      "#{issuer}/protocol/openid-connect/logout?#{query.to_query}"
    end

    def verifying_via_email?
      return false if resource.blank?

      stored_path = session[stored_location_key_for(resource)] || ""
      stored_path[0..5] == "/email"
    end
end
