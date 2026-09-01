class InternalApi::AiFeaturesController < InternalApi::BaseController
  def show
    render json: {
      status:     "online",
      checked_at: Time.current.iso8601,
      ai:         Admin::AiFeaturesService.call
    }
  end
end
