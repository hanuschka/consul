require_dependency Rails.root.join("app", "controllers", "users", "sessions_controller").to_s

class Users::SessionsController < Devise::SessionsController
  def destroy
    @stored_location = stored_location_for(:user)
    @keycloak_id_token = current_user.keycloak_id_token
    super
  end

  private

    def respond_to_on_destroy(non_navigational_status: :no_content)
      respond_to do |format|
        format.all { head non_navigational_status }
        format.any(*navigational_formats) do
          redirect_to after_sign_out_path_for(resource_name),
                      status: Devise.responder.redirect_status,
                      allow_other_host: @keycloak_id_token.present?
        end
      end
    end

    def after_sign_out_path_for(resource)
      if @keycloak_id_token.present?
        redirect_path = @stored_location.present? && !@stored_location.match("management") ? @stored_location : super
        redirect_url = request.base_url + redirect_path
        Rails.application.secrets.openid_connect_sign_out_uri +
          "?id_token_hint=" + @keycloak_id_token +
          "&post_logout_redirect_uri=" + redirect_url
      else
        super
      end
    end
end
