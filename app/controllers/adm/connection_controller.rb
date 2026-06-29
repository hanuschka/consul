module Adm
  class ConnectionController < Adm::BaseController
    def show
      authorize [:adm, :connection]

      @breadcrumbs = [
        { name: t("adm.menu.items.developer"), icon: "logo_dev" },
        { name: t("adm.connection.show.title") }
      ]

      check = DtApi::ConnectionCheck.call

      @dt_connected = check.dt_connected
      @api_accessible = check.api_accessible
      @connection_works = check.connection_works
      @status_code = check.status_code
      @status_data = check.status_data
      @dt_connected_error = check.dt_connected_error
      @api_accessible_error = check.api_accessible_error
      @connection_error = check.connection_error
      @all_checks_passed = check.all_checks_passed?
    end
  end
end
