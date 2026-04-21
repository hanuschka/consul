class Admin::ConnectionController < Admin::BaseController
  def index
    @dt_connected = Dt.connected?
    @api_accessible = false
    @connection_works = false

    unless @dt_connected
      dt_client = InternalApiClient.dt
      @dt_connected_error =
        if dt_client.blank?
          "No registered DT API client found (InternalApiClient with name 'DT')."
        else
          "DT API client found but service_api_token is missing."
        end
    end

    begin
      response = DtApi::Client.new.connection.status
      @status_code = response.code
      @status_data = response.parsed_response
      @api_accessible = !response.code.between?(500, 599)
      @connection_works =
        response.code == 200 &&
        @status_data.is_a?(Hash) &&
        @status_data["authenticated"] == true

      unless @api_accessible
        @api_accessible_error = "HTTP #{@status_code}\n#{@status_data.inspect}"
      end
    rescue StandardError => e
      @connection_error = e.message
      @api_accessible_error = e.message
    end
  end
end
