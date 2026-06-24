class DtApi::ConnectionCheck
  Result = Struct.new(
    :dt_connected,
    :api_accessible,
    :connection_works,
    :status_code,
    :status_data,
    :dt_connected_error,
    :api_accessible_error,
    :connection_error,
    :dt_domain,
    keyword_init: true
  ) do
    def all_checks_passed?
      dt_connected && api_accessible && connection_works
    end

    def error_message
      connection_error || api_accessible_error || dt_connected_error
    end

    def as_json_payload
      {
        connected: dt_connected,
        api_accessible: api_accessible,
        authenticated: connection_works,
        status_code: status_code,
        error: error_message,
        dt_domain: dt_domain
      }
    end
  end

  def self.call
    new.call
  end

  def call
    dt_connected = Dt.connected?
    dt_connected_error = dt_connected ? nil : dt_connected_error_message

    api_accessible = false
    connection_works = false
    status_code = nil
    status_data = nil
    api_accessible_error = nil
    connection_error = nil

    begin
      response = DtApi::Client.new.connection.status
      status_code = response.code
      status_data = response.parsed_response
      api_accessible = !response.code.between?(500, 599)
      connection_works =
        response.code == 200 &&
        status_data.is_a?(Hash) &&
        status_data["authenticated"] == true

      if api_accessible.blank?
        api_accessible_error = "HTTP #{status_code}\n#{status_data.inspect}"
      end
    rescue StandardError => e
      connection_error = e.message
      api_accessible_error = e.message
    end

    Result.new(
      dt_connected: dt_connected,
      api_accessible: api_accessible,
      connection_works: connection_works,
      status_code: status_code,
      status_data: status_data,
      dt_connected_error: dt_connected_error,
      api_accessible_error: api_accessible_error,
      connection_error: connection_error,
      dt_domain: dt_domain_info
    )
  end

  private

    def dt_connected_error_message
      dt_client = InternalApiClient.dt

      if dt_client.blank?
        I18n.t("adm.connection.show.errors.no_client")
      else
        I18n.t("adm.connection.show.errors.no_token")
      end
    end

    def dt_domain_info
      {
        secrets_domain: Dt.domain,
        secrets_url: Dt.url,
        client_domain: InternalApiClient.dt&.domain
      }
    end
end
