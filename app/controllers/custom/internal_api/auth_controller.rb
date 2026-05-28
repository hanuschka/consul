class InternalApi::AuthController < ActionController::API
  def generate_frame_sign_in_token
    user = User.find(params[:user_id])
    user.generate_frame_sign_in_token!

    render json: {
      frame_sign_in_token: user.frame_sign_in_token,
      frame_sign_in_token_valid_until: user.frame_sign_in_token_valid_until
    }
  end

  def validate_iframe_token
    data = iframe_token_verifier.verify(
      params[:token],
      purpose: :iframe_auth
    )

    if data["exp"].to_i < Time.current.to_i
      render json: { valid: false, error: "Token expired" }, status: :unauthorized

      return
    end

    render json: { valid: true, user_id: data["user_id"] }
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    render json: { valid: false, error: "Invalid token" }, status: :unauthorized
  end

  def generate_iframe_token
    user = User.find(params[:user_id])

    token = iframe_token_verifier.generate(
      { "user_id" => user.id, "exp" => 5.minutes.from_now.to_i },
      purpose: :iframe_auth
    )

    render json: { iframe_token: token }
  end

  private

  def iframe_token_verifier
    ActiveSupport::MessageVerifier.new(
      Rails.application.secret_key_base,
      digest: "SHA256"
    )
  end
end
