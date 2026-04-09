module Adm
  class ConnectionController < Adm::BaseController
    def show
      authorize [:adm, :connection]

      @breadcrumbs = [
        { name: t("adm.menu.items.developer"), icon: "logo_dev" },
        { name: t("adm.connection.show.title") }
      ]

      @dt_connected = Dt.connected?
      @api_accessible = false
      @connection_works = false

      if @dt_connected.blank?
        dt_client = InternalApiClient.dt

        @dt_connected_error =
          if dt_client.blank?
            I18n.t("adm.connection.show.errors.no_client")
          else
            I18n.t("adm.connection.show.errors.no_token")
          end
      end

      check_api_connection
    end

    private

      def check_api_connection
        response = DtApi::Client.new.connection.status
        @status_code = response.code
        @status_data = response.parsed_response
        @api_accessible = !response.code.between?(500, 599)
        @connection_works =
          response.code == 200 &&
          @status_data.is_a?(Hash) &&
          @status_data["authenticated"] == true

        if @api_accessible.blank?
          @api_accessible_error = "HTTP #{@status_code}\n#{@status_data.inspect}"
        end
      rescue StandardError => e
        @connection_error = e.message
        @api_accessible_error = e.message
      end
  end
end
