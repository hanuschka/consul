# TODO: check if this controller still nededed
class IframeSessionsController < ActionController::Base
  skip_authorization_check
  skip_forgery_protection

  skip_before_action :authentificate_frame_session_user!

#   def create
#     user = User.find_by(frame_sign_in_token: params[:frame_sign_in_token])

#     cookies[:test_cookie_iframe] = "true"
#     if user.present? && user.frame_sign_in_token_valid?
#       set_frame_session(user)
#     end
#   end
end
