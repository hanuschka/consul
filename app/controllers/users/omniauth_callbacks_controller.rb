class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: %i[process_bund_id_response]

  def send_bund_id_request
    request.headers["Turbolinks-Referrer"] = nil
    saml_redirect_request_url = BundIdServices::RedirectRequestMaker.call

    redirect_to(saml_redirect_request_url, allow_other_host: true)
  end

  def process_bund_id_response
    auth_data = BundIdServices::ResponseProcessor.call(params[:SAMLResponse])
    sign_in_with :bund_id_login, :bund_id, auth_data
  end

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

      if save_user
        identity.update!(user: @user)
        update_user_address(auth) if auth.extra.raw_info.street_address.present?
        @user.verify! if auth.extra.raw_info.verification_level.in?(["STORK-QAA-Level-3", "STORK-QAA-Level-4"])
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

    def update_user_address(auth_data)
      full_street_address = auth_data.extra.raw_info.street_address
      regex = /(?<street_name>[\p{L}\d\s,.\-äöüßÄÖÜ]+?)\s*(?<street_number>\d+)\s*(?<street_number_extension>[a-zA-Z\s]*)/
      match = full_street_address.match(regex)

      if match
        registered_address_city = RegisteredAddress::City.where(
          "LOWER(name) = ?", auth_data.extra.raw_info.locality_name.downcase
        ).first

        registered_address_street = RegisteredAddress::Street.where(
          "LOWER(name) = ? AND plz = ?",
          match[:street_name].gsub(/[,\s]+$/, '').downcase,
          auth_data.extra.raw_info.postal_code
        ).first

        if registered_address_city && registered_address_street
          registered_address = RegisteredAddress.find_by(
            registered_address_city: registered_address_city.id,
            registered_address_street: registered_address_street.id,
            street_number: match[:street_number].strip,
            street_number_extension: match[:street_number_extension].strip.presence
          )
        end

        @user.update!(registered_address: registered_address) if registered_address

        @user.update!(
          street_name: match[:street_name].gsub(/[,\s]+$/, ''),
          street_number: match[:street_number].strip,
          street_number_extension: match[:street_number_extension].strip.presence,
          city_name: auth_data.extra.raw_info.locality_name,
          plz: auth_data.extra.raw_info.postal_code
        )
      end
    end
end
