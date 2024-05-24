require_dependency Rails.root.join("app", "controllers", "users", "omniauth_callbacks_controller").to_s

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: %i[process_bund_id_response]

  def send_bund_id_request
    request.headers["Turbolinks-Referrer"] = nil
    saml_redirect_request_url = BundIdServices::RedirectRequestMaker.call

    redirect_to(saml_redirect_request_url, allow_other_host: true)
  end

  def process_bund_id_response
    BundIdServices::ResponseProcessor.call(params[:SAMLResponse])
  end

  def after_sign_in_path_for(resource)
    if resource.registering_with_oauth
      finish_signup_path
    else
      super(resource)
    end
  end

  private

    def sign_in_with(feature, provider)
      raise ActionController::RoutingError, "Not Found" unless Setting["feature.#{feature}"]

      auth = request.env["omniauth.auth"]

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

    def save_user
      @user.save || @user.save_requiring_finish_signup
    end
end
