class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def twitter
    sign_in_with :twitter_login, :twitter
  end

  def facebook
    sign_in_with :facebook_login, :facebook
  end

  def google_oauth2
    sign_in_with :google_login, :google_oauth2
  end

  def wordpress_oauth2
    sign_in_with :wordpress_login, :wordpress_oauth2
  end

  def after_sign_in_path_for(resource)
    if resource.registering_with_oauth
      finish_signup_path
    else
      super(resource)
    end
  end

  private

    def sign_in_with(feature, provider, auth_data = nil)
      raise ActionController::RoutingError, "Not Found" unless Setting["feature.#{feature}"]

      auth = auth_data || request.env["omniauth.auth"]

      identity = Identity.first_or_create_from_oauth(auth)
      identity.update!(auth_data: auth)
      @user = current_user || identity.user || User.first_or_initialize_for_oauth(auth)

      update_email(auth)

      if save_user
        identity.update!(user: @user)
        update_user_address(auth) if auth.extra.raw_info.street_address.present?
        @user.verify! if auth.extra.raw_info.verification_level.in?(["STORK-QAA-Level-3", "STORK-QAA-Level-4"])
        sign_in_and_redirect @user, event: :authentication
        preexisting_flash = flash[:notice]
        set_flash_message(:notice, :success, kind: provider.to_s.capitalize) if is_navigational_format?
        flash[:notice] += " #{preexisting_flash}" if preexisting_flash
      else
        session["devise.#{provider}_data"] = auth
        redirect_to new_user_registration_path
      end
    end

    def save_user
      @user.save || @user.save_requiring_finish_signup
    end
end
