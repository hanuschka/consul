class Admin::ConnectionController < Admin::BaseController
  def index
    @dt_connected = Dt.connected?
    @api_accessible = false
    @connection_works = false

    begin
      response = DtApi::Client.new.connection.status
      @status_code = response.code
      @status_data = response.parsed_response
      @api_accessible = !response.code.between?(500, 599)
      @connection_works =
        response.code == 200 &&
        @status_data.is_a?(Hash) &&
        @status_data["authenticated"] == true
    rescue StandardError => e
      @connection_error = e.message
    end
  end
end
