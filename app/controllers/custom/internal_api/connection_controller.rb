class InternalApi::ConnectionController < InternalApi::BaseController
  def dt_status
    render json: DtApi::ConnectionCheck.call.as_json_payload
  end

  def update_client_info
    render json: Dt.map_settings.merge(logo: logo_payload)
  end

  private

    def logo_payload
      {
        filename: File.basename(Dt.logo_path),
        content_type: "image/png",
        data: Base64.strict_encode64(File.binread(Dt.logo_path))
      }
    end
end
