class Api::Auth::RotateTokenController < Api::BaseController
  def create
    current_client.regenerate_access_token
    render json: { data: { access_token: current_client.access_token } }, status: :ok
  end
end
