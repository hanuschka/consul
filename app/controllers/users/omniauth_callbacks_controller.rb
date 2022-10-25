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

  def servicekonto_nrv
    sign_in_with :servicekonto_nrv_login, :servicekonto_nrv
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
      user_should_be_verified = false

      if provider == :servicekonto_nrv
        if current_user.present? && current_user.email != auth.info.email
          existing_non_logined_user_with_same_email = User.find_by(email: auth.info.email)

          if existing_non_logined_user_with_same_email.present?
            flash[:alert] = "Please log in with your other account: #{auth.info.email}"
            redirect_to(account_path) and return
          else
            current_user.update!(email: auth.info.email)
          end
        end

        user_should_be_verified = (
          @user.new_record? || (current_user.present? && current_user.verified_at.blank? && existing_non_logined_user_with_same_email.blank?)
        )
      end

      if provider == :servicekonto_nrv && @user.new_record?
        # TODO check if email confimation nedeed
        @user.skip_confirmation!
        @user.skip_confirmation_notification!
      end

      if save_user
        identity.update!(user: @user)

        if provider == :servicekonto_nrv && user_should_be_verified
          verify_user_with_servicekonto(@user, auth)
        end

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

    def verify_user_with_servicekonto(user, auth)
      address_data = auth.extra.raw_info["http://www.governikus.de/sk/addresses"]
      street = address_data.street_address

      geozone = Geozone.find_with_plz(address_data.postal_code)

      user.update!(
        street_name: street.gsub(/\s\d+/, ""),
        street_number: street.match(/\d+/)[0],
        city_name: address_data.locality,
        verified_at: Time.current,
        geozone: geozone,
        date_of_birth: DateTime.parse(auth.extra.raw_info.birthdate),
        plz: address_data.postal_code
      )
    end
end
