module MarketplaceServices
  class BrevoContactExporter < ApplicationService
    # Exactly the fields the proxy maps onto Brevo attributes (EMAIL, CONSUL_PROFILNAME,
    # CONSUL_NEWSLETTER, CONSUL_DATUM_REGISTRIERUNG) — anything else it discards. Serialising the
    # whole user record sent identity and auth material Brevo has no use for, and made every event
    # that touched any column look like a contact change — a login bumping updated_at, a budget
    # vote setting balloted_heading_id — re-creating contacts deleted in Brevo (BES-1574).
    EXPORTED_ATTRIBUTES = %w[email username newsletter created_at].freeze

    def initialize(user_id, export_type, email = nil)
      @export_type = export_type
      @contact_json = contact_for(user_id, email).to_json
      @proxi_app_token = Rails.application.secrets.marketplace_services[:brevo_contact_exporter]
    end

    def call
      return unless @proxi_app_token.present?

      # HTTParty.post("http://localhost:3002/api/v1/brevo_contact/export",
      HTTParty.post("https://proxy.demokratie.today/api/v1/brevo_contact/export",
                    body: { contact: @contact_json, export_type: @export_type }.to_json,
                    headers: { "Content-Type" => "application/json", "Proxi-App-Token" => @proxi_app_token })
    end

    private

      # A deletion cannot read the user back: erase has already nulled the email by the time the
      # job runs, and after_destroy leaves nothing to find at all. The caller passes the address
      # it still had, which is the only thing the proxy needs to identify the Brevo contact.
      def contact_for(user_id, email)
        return { "email" => email } if @export_type == "delete"

        User.find(user_id).slice(*EXPORTED_ATTRIBUTES)
      end
  end
end
