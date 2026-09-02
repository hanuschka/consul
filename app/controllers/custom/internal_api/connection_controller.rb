class InternalApi::ConnectionController < InternalApi::BaseController
  def dt_status
    render json: DtApi::ConnectionCheck.call.as_json_payload
  end

  def update_client_info
    render json: Dt.map_settings.merge(logo: logo_payload)
  end

  def sync_client_domain
    dt_client = InternalApiClient.dt

    if dt_client.blank?
      render json: { error: I18n.t("adm.connection.show.errors.no_client") },
             status: :not_found and return
    end

    if Dt.domain.blank?
      render json: { error: "DT domain is not configured in secrets" },
             status: :unprocessable_entity and return
    end

    previous_domain = dt_client.domain
    dt_client.update!(domain: Dt.domain)

    render json: {
      previous_domain: previous_domain,
      domain: dt_client.domain,
      changed: previous_domain != dt_client.domain
    }
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
