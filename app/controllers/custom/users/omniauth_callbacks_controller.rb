require_dependency Rails.root.join("app", "controllers", "users", "omniauth_callbacks_controller").to_s

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def open_rathaus
    raise ActionController::RoutingError, "Not Found" unless Setting["feature.open_rathaus_login"]

    auth = request.env["omniauth.auth"]
    provider = auth.provider.to_sym

    identity = Identity.first_or_create_from_oauth(auth)
    @user = current_user || identity.user || User.first_or_initialize_for_oauth(auth)

    if save_user
      identity.update!(user: @user)
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: provider.to_s.capitalize) if is_navigational_format?
    else
      session["devise.#{provider}_data"] = auth
      redirect_to new_user_registration_path
    end
  end

  def after_sign_in_path_for(resource)
    if resource.registering_with_oauth && resource.username.blank?
      finish_signup_path
    else
      super(resource)
    end
  end

  private

    def save_user
      @user.save_requiring_finish_signup
    end
end
