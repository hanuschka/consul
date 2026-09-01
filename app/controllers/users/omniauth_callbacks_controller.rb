class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: %i[process_bund_id_response]

  def send_bund_id_request
    saml_redirect_request_url = BundIdServices::RedirectRequestMaker.call(user_id: current_user&.id, purpose: params[:purpose])
    request.session_options[:skip] = true

    redirect_to(saml_redirect_request_url, allow_other_host: true)
  end

  def process_bund_id_response
    auth_data = BundIdServices::ResponseProcessor.call(params[:SAMLResponse])

    if params["RelayState"].present?
      relay_state = RelayState.where("created_at > ?", 1.hour.ago).find_by(token: params["RelayState"])

      if relay_state.present?
        user_id = relay_state.data["user_id"]
        purpose = relay_state.data["purpose"]
        request_time = relay_state.created_at.to_i
        relay_state.destroy!
      end
    end

    if user_id.present? && purpose == "verification"
      if Time.zone.at(request_time) < 15.minutes.ago
        flash[:error] = t("custom.users.omniauth.bund_id.verification_request_expired")
        redirect_to root_path
      else
        user = User.find(user_id)
        user.update_columns(user_attributes_from(auth_data))
        user.reload
        user.verify! if user.last_stork_level.in?(["STORK-QAA-Level-3", "STORK-QAA-Level-4"])
        sign_in user

        if user.verified?
          flash[:notice] = t("custom.users.omniauth.bund_id.verification_successfull")
        else
          flash[:alert] = t("custom.users.omniauth.bund_id.verification_failed")
        end

        redirect_to account_path
      end
    else
      sign_in_with :bund_id_login, :bund_id, auth_data
    end
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

  def bochum_id
    sign_in_with :bochum_id_login, :bochum_id
  end

  def kobil
    sign_in_with :kobil_login, :kobil
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

      @user = identity.user || User.first_or_initialize_for_oauth(auth)

      @user.assign_attributes(user_attributes_from(auth))

      if save_user
        identity.update!(user: @user)
        preexisting_flash = flash[:notice]
        set_flash_message(:notice, :success, kind: provider_label(provider)) if is_navigational_format?
        flash[:notice] += " #{preexisting_flash}" if preexisting_flash
        flash[:notice] = t("custom.users.omniauth.verification_successfull") if @user.level_three_verified?
        sign_in_and_redirect @user, event: :authentication
      else
        session["devise.#{provider}_data"] = auth
        redirect_to new_user_registration_path
      end
    end

    def save_user
      @user.save || @user.save_requiring_finish_signup
    end

    def provider_label(provider)
      case provider
      when :bund_id
        "BundID"
      when :kobil
        "KOBIL"
      else
        provider.to_s.capitalize
      end
    end

    def user_attributes_from(auth_data)
      return kobil_user_attributes_from(auth_data) if auth_data.try(:provider).to_s == "kobil"

      user_attributes = {
        first_name:              auth_data.info&.first_name&.capitalize,
        last_name:               auth_data.info&.last_name&.capitalize,
        gender:                  auth_data.extra&.raw_info&.gender,
        date_of_birth:           (Date.parse(auth_data.extra.raw_info&.date_of_birth) rescue nil),
        last_stork_level:        auth_data.extra&.raw_info&.verification_level,
        city_name: auth_data.extra.raw_info.locality_name&.capitalize,
        plz: auth_data.extra.raw_info.postal_code
      }

      full_street_address = auth_data.extra.raw_info.street_address
      regex = /(?<street_name>[\p{L}\d\s,.-]+?)\s*(?<street_number>\d+)\s*(?<street_number_extension>[a-zA-Z\s]*)/
      match = full_street_address&.match(regex)
      registered_address = nil

      if match
        registered_address_city = RegisteredAddress::City.where(
          "LOWER(name) = ?", auth_data.extra.raw_info.locality_name.downcase
        ).first

        registered_address_street = RegisteredAddress::Street.where(
          "LOWER(name) = ? AND plz = ?",
          match[:street_name].downcase.gsub(/[,\s]+$/, "").gsub("ss", "ß"),
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

        user_attributes.merge!(
          {
            registered_address_id: registered_address&.id,
            street_name: match[:street_name].capitalize.gsub(/[,\s]+$/, "").gsub("ss", "ß"),
            street_number: match[:street_number].strip,
            street_number_extension: match[:street_number_extension].strip.presence,
          }
        )
      end

      user_attributes.reject { |_, v| v.blank? }
    end

    def kobil_user_attributes_from(auth_data)
      raw_info = auth_data.extra&.raw_info

      user_attributes = {
        first_name:    auth_data.info&.first_name&.capitalize,
        last_name:     auth_data.info&.last_name&.capitalize,
        date_of_birth: (Date.parse(raw_info&.birthdate.to_s) rescue nil)
      }

      if Setting["feature.kobil_address_verification"].present?
        user_attributes.merge!(kobil_address_attributes_from(raw_info))
      end

      user_attributes.reject { |_, v| v.blank? }
    end

    def kobil_address_attributes_from(raw_info)
      address = raw_info&.address
      return {} if address.blank?

      {
        street_name: address["street_address"].presence&.capitalize,
        plz:         address["postal_code"].presence,
        city_name:   address["locality"].presence&.capitalize
      }
    end
end
