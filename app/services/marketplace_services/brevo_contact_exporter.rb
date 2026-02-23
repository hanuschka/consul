module MarketplaceServices
  class BrevoContactExporter < ApplicationService
    def initialize(user_id, export_type)
      user = User.find(user_id)
      @export_type = export_type
      @contact_json = user.as_json.merge("current_sign_in_at" => user.current_sign_in_at).to_json
      @proxi_app_token = Rails.application.secrets.marketplace_services[:brevo_contact_exporter]
    end

    def call
      return unless @proxi_app_token.present?

      # HTTParty.post("http://localhost:3002/api/v1/brevo_contact/export",
      HTTParty.post("https://proxy.demokratie.today/api/v1/brevo_contact/export",
                    body: { contact: @contact_json, export_type: @export_type }.to_json,
                    headers: { "Content-Type" => "application/json", "Proxi-App-Token" => @proxi_app_token })
    end
  end
end
