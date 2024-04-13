module MarketplaceServices
  class BrevoContactExporter < ApplicationService
    def initialize(user_id)
      @contact_json = User.find(user_id).to_json
      @proxi_app_token = Rails.application.secrets.marketplace_services[:brevo_contact_exporter]
    end

    def call
      return unless @proxi_app_token.present?

      HTTParty.post("https://proxy.demokratie.today/api/v1/brevo_contact/export",
                    body: { contact: @contact_json }.to_json,
                    headers: { "Content-Type" => "application/json", "Proxi-App-Token" => @proxi_app_token })
    end
  end
end
