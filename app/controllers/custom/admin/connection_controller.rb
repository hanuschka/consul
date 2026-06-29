class Admin::ConnectionController < Admin::BaseController
  def index
    check = DtApi::ConnectionCheck.call

    @dt_connected = check.dt_connected
    @api_accessible = check.api_accessible
    @connection_works = check.connection_works
    @status_code = check.status_code
    @status_data = check.status_data
    @dt_connected_error = check.dt_connected_error
    @api_accessible_error = check.api_accessible_error
    @connection_error = check.connection_error
  end
end
