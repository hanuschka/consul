# frozen_string_literal: true

class Api::NotFoundController < Api::BaseController
  skip_before_action :authenticate_api_client!

  def index
    render json: {
      error: {
        type: 'not_found',
        messages: ["The requested API endpoint does not exist. Please check the URL and try again."]
      }
    }, status: :not_found
  end
end
