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

      if prevent_verification_if_identity_taken?(auth, provider)
        flash[:notice] = t("custom.users.omniauth.identity_taken")
        redirect_to account_path
      else
        identity = Identity.first_or_create_from_oauth(auth)
        identity.update!(auth_data: auth)
        @user = current_user || identity.user || User.first_or_initialize_for_oauth(auth)
        @user.last_stork_level = auth.extra&.raw_info&.verification_level

        update_with_oauth_data(auth)
        update_email(auth)
        update_user_address(auth) if auth.extra.raw_info.street_address.present?

        if save_user
          identity.update!(user: @user)
          @user.verify! if @user.errors.blank? && @user.last_stork_level.in?(["STORK-QAA-Level-3", "STORK-QAA-Level-4"])
          sign_in_and_redirect @user, event: :authentication
          preexisting_flash = flash[:notice]
          set_flash_message(:notice, :success, kind: provider_name(provider)) if is_navigational_format?
          flash[:notice] += " #{preexisting_flash}" if preexisting_flash
          flash[:notice] = t("custom.users.omniauth.verification_successfull") if @user.level_three_verified?
        else
          session["devise.#{provider}_data"] = auth
          redirect_to new_user_registration_path
        end
      end
    end

    def save_user
      @user.save || @user.save_requiring_finish_signup
    end

    def update_with_oauth_data(auth)
      return unless @user.persisted?

      @user.first_name = auth.info&.first_name&.capitalize || @user.first_name
      @user.last_name = auth.info&.last_name&.capitalize || @user.last_name
      @user.date_of_birth = (Date.parse(auth.extra.raw_info&.date_of_birth) rescue nil) || @user.date_of_birth
      @user.plz = auth.extra.raw_info&.postal_code || @user.plz
    end

    def update_email(auth)
      return if auth.info.email == @user.email

      if User.with_hidden.where.not(id: @user.id).find_by(email: auth.info.email).present?
        flash[:notice] = t("custom.users.omniauth.email_taken_html")
      else
        @user.skip_reconfirmation!
        @user.update!(email: auth.info.email)
        flash[:notice] = t("custom.users.omniauth.email_updated", email: auth.info.email)
      end
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

        @user.registered_address = registered_address
        @user.street_name = match[:street_name].capitalize.gsub(/[,\s]+$/, "").gsub("ss", "ß")
        @user.street_number = match[:street_number].strip
        @user.street_number_extension = match[:street_number_extension].strip.presence
        @user.city_name = auth_data.extra.raw_info.locality_name&.capitalize
        @user.plz = auth_data.extra.raw_info.postal_code
      end
    end

    def prevent_verification_if_identity_taken?(auth, provider)
      return false unless current_user.present?

      corresponding_identity = Identity.find_by(provider: provider, uid: auth.uid)
      return false if corresponding_identity.blank?

      corresponding_identity.user != current_user
    end

    def provider_name(provider)
      return "BundID" if provider == :bund_id

      provider.to_s.capitalize
    end
end
