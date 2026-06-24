class InternalApi::ConnectionController < InternalApi::BaseController
  def dt_status
    render json: DtApi::ConnectionCheck.call.as_json_payload
  end
end
