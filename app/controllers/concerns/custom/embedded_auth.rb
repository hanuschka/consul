module EmbeddedAuth
  extend ActiveSupport::Concern

  included do
    before_action :set_iframe_content_security_policy
    prepend_before_action :authentificate_frame_session_user!

    helper_method :embedded? #, :frame_temp_token_valid?
    helper_method :skip_forgery_protection_for_frame_session?, :frame_session_from_authorized_source?, :frame_session

    skip_forgery_protection if: :skip_forgery_protection_for_frame_session?
  end

  private

    def set_iframe_content_security_policy
      response.headers["Content-Security-Policy"] =
        "frame-ancestors #{Dt.url}"
    end

    def embedded?
      @embedded ||=
        (params[:embedded] == "true" || request.headers["HTTP_X_EMBEDDED_FRAME"] == "true")
    end

    def skip_forgery_protection_for_frame_session?
      @_frame_session_authentificated ||=
        frame_session_from_authorized_source? && current_user.present?
    end

    def frame_session_from_authorized_source?
      @_frame_session_from_authorized_source ||=
        frame_session.present? && origin_allowed?
    end


    def frame_session
      return @_frame_session if @_frame_session.present?
      return if cookies.encrypted[:frame_session].nil?

      @_frame_session ||=
        begin
          JSON.parse(cookies.encrypted[:frame_session]).with_indifferent_access
        rescue
          nil
        end
    end

    def authentificate_frame_session_user!
      return unless embedded?

      if frame_session_from_authorized_source?
        user = User.find(frame_session["user_id"])

        if user.present?
          set_frame_session(user)
        else
          raise "Invalid auth"
        end
      elsif params[:frame_sign_in_token].present?
        user = User.find_by(frame_sign_in_token: params[:frame_sign_in_token])

        if user.present? && user.frame_sign_in_token_valid?
          set_frame_session(user)
        else
          raise "Error sign in"
        end
      end
    end

    def set_frame_session(user)
      new_frame_session = { user_id: user.id }

      cookies.encrypted[:frame_session] = {
        value: new_frame_session.to_json,
        same_site: :none,
        secure: true,
        httponly: true,
        expires: 5.hours
      }

      Current.frame_current_user = user
      # binding.pry
      # request.env["warden"].set_user(user, store: false)
      sign_in(user, store: false)
      # bypass_sign_in(user)
    end

    def default_url_options
      @default_url_options ||= gen_default_url_options(super)
    end

    def gen_default_url_options(options)
      options = options.presence || {}

      options =
        if params[:embedded].present?
          options.merge({ embedded: params[:embedded] })
        else
          {}
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
    end

    # def frame_csrf_token_valid?(current_frame_csrf_token)
    #   # if Rails.env.development? && ENV["TURN_ON_DEV_FRAME_CSRF_PROTECTION"] != "true"
    #   #   return true
    #   # end

    #   current_frame_csrf_token && current_frame_csrf_token == params[:frame_csrf_token]
    # end
end
