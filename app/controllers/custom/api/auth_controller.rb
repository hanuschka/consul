class Api::AuthController < Api::BaseController
  skip_forgery_protection

  def generate_temporary_auth_token
    user = User.find(params[:user_id])
    user.generate_expiring_temporary_auth_token!

    render json: {
      temporary_auth_token: user.temporary_auth_token,
      temporary_auth_token_valid_until: user.temporary_auth_token_valid_until
    }
  end
end
