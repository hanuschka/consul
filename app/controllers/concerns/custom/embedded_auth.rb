module EmbeddedAuth
  extend ActiveSupport::Concern

  included do
    before_action :set_iframe_content_security_policy
    helper_method :embedded? #, :frame_temp_token_valid?
    helper_method :frame_access_code_valid? #, :frame_temp_token_valid?
    helper_method :embedded_and_frame_access_code_valid?
    skip_forgery_protection if: :frame_session_from_authorized_source?
  end

  private

    def set_iframe_content_security_policy
      response.headers["Content-Security-Policy"] =
        "frame-ancestors #{Rails.application.secrets.dt[:url]}"
    end

    def embedded?
      @embedded ||=
        (params[:embedded] == "true")
    end

    def frame_access_code_valid?(projekt)
      params[:frame_code] = projekt.frame_access_code
    end

    def embedded_and_frame_access_code_valid?(projekt)
      embedded? && frame_access_code_valid?(projekt)
    end

    def frame_session_from_authorized_source?
      Current.frame_session_from_authorized_source && Current.frame_current_user.present?
    end

    def authentificate_frame_session_user!
      return if cookies[:frame_session].blank?

      frame_session = JSON.parse(cookies.encrypted[:frame_session]).with_indifferent_access
      Current.frame_csrf_token = frame_session[:frame_csrf_token]

      user = User.find(frame_session["user_id"])

      frame_session_from_authorized_source =
        origin_allowed? && frame_csrf_token_valid?

      Current.frame_session_from_authorized_source = frame_session_from_authorized_source

      if frame_session_from_authorized_source
        if user.present?
          update_frame_session_data(
            user,
            gen_new_frame_csrf_token: !request.xhr?
          )
        else
          raise "Invalid auth"
        end
      end
    end

    def update_frame_session_data(user, gen_new_frame_csrf_token: true)
      active_frame_csrf_token =
        if gen_new_frame_csrf_token
          SecureRandom.base64(32)
        elsif Current.frame_csrf_token.present?
          Current.frame_csrf_token
        end

      new_frame_session = { user_id: user.id }

      if active_frame_csrf_token.present?
        new_frame_session[:frame_csrf_token] = active_frame_csrf_token
      end

      cookies.encrypted[:frame_session] = {
        value: new_frame_session.to_json,
        same_site: :none,
        secure: true,
        httponly: true,
        expires: 5.hour
      }

      Current.new_frame_csrf_token = active_frame_csrf_token
      Current.frame_current_user = user
      request.env["warden"].set_user(user)
    end

    def default_url_options
      @default_url_options ||= gen_default_url_options(super)
    end

    def gen_default_url_options(options)
      options = options.presence || {}

      options =
        if params[:temp_token].present?
          options.merge({ temp_token: params[:temp_token] })
        else
          {}
        end

      options =
        if params[:embedded].present?
          options.merge({ embedded: params[:embedded] })
        else
          {}
        end

      options =
        # TODO move this to JS
        if Current.new_frame_csrf_token.present? && Current.frame_session_from_authorized_source
          options.merge({ frame_csrf_token: Current.new_frame_csrf_token })
        else
          options
        end

      options
    end

    def origin_allowed?
      return true if request.get?

      frame_allowed_domain?(request.origin)
    end

    def frame_allowed_domain?(url)
      return false if url.blank?

      url_domain = URI.parse(url).host

      (Rails.application.secrets.server_name || request.host) == url_domain
    # rescue URI::InvalidURIError
    #   return false
    end

    def frame_csrf_token_valid?
      if Rails.env.development? && ENV["TURN_ON_DEV_FRAME_CSRF_PROTECTION"] != "true"
        return true
      end

      Current.frame_csrf_token.present? &&
        Current.frame_csrf_token == params[:frame_csrf_token]
    end

    # def frame_temp_token_valid?
    #   return false if params[:temp_token].blank?
    #
    #   user = User.find_by(temporary_auth_token: params[:temp_token])
    #
    #   user.present? && user.temporary_auth_token_valid?
    # end
end
