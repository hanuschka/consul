class Api::AuthController < Api::BaseController
  def generate_frame_sign_in_token
    user = User.find(params[:user_id])
    user.generate_frame_sign_in_token!

    render json: {
      frame_sign_in_token: user.frame_sign_in_token,
      frame_sign_in_token_valid_until: user.frame_sign_in_token_valid_until
    }
  end
end
