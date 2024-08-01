class IframeSessionsController < ActionController::Base
  include EmbeddedAuth
  skip_authorization_check
  skip_forgery_protection

  def create
    user = User.find_by(temporary_auth_token: params[:temporary_auth_token])

    if user.present? && user.temporary_auth_token_valid?
      update_frame_session_data(
        user,
        gen_new_frame_csrf_token: true
      )
    end

    if params[:redirect_to].present? &&
        frame_allowed_domain?(params[:redirect_to])

      redirect_uri = URI.parse(params[:redirect_to])
      redirect_uri_params =
        URI.decode_www_form(redirect_uri.query || "")

      redirect_uri_params << ["frame_csrf_token", Current.new_frame_csrf_token]

      redirect_uri.query = URI.encode_www_form(redirect_uri_params)

      redirect_to redirect_uri.to_s
    end
  end
end
