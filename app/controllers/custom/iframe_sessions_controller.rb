class IframeSessionsController < ActionController::Base
  include EmbeddedAuth
  skip_authorization_check
  skip_forgery_protection

  def create
    user = User.find_by(frame_sign_in_token: params[:frame_sign_in_token])

    if user.present? && user.frame_sign_in_token_valid?
      update_frame_session_data(user)
    end

    if params[:redirect_to].present? &&
        frame_allowed_domain?(params[:redirect_to])
      redirect_to params[:redirect_to]
    end
  end
end
