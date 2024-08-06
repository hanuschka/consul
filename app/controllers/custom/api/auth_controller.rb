class Api::AuthController < Api::BaseController
  skip_forgery_protection

  def generate_frame_sign_in_token
    user = User.find(params[:user_id])
    user.generate_frame_sign_in_token!

    render json: {
      frame_sign_in_token: user.frame_sign_in_token,
      frame_sign_in_token_valid_until: user.frame_sign_in_token_valid_until
    }
  end

  # def generate_temporary_auth_token
  #   user = User.find(params[:user_id])
  #   # user.generate_temporary_auth_token!
  #
  #   render json: {
  #     temporary_auth_token: user.temporary_auth_token,
  #     temporary_auth_token_valid_until: user.temporary_auth_token_valid_until
  #   }
  # end
end
