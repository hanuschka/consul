class Whatsapp::WebhookStatusService < ApplicationService
  # Reads the registration back from 360dialog. The header value is compared in
  # memory and only its length is exposed, so the secret never reaches a view.
  def initialize(expected_base_url: nil)
    @expected_base_url = expected_base_url
  end

  def call
    return unreachable if !::Whatsapp.configured?

    response = WhatsappApi::Client.new.webhooks.show

    return unreachable if !response.success?

    build_status(response.parsed_response.to_h)
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] webhook status check failed: #{e.class} - #{e.message}")

    unreachable
  end

  private

    def build_status(payload)
      registered_url = payload["url"].to_s
      header_value = registered_header_value(payload)

      {
        reachable: true,
        registered_url: registered_url,
        url_matches: registered_url.present? && registered_url == expected_url,
        expected_url: expected_url,
        header_length: header_value.length,
        header_matches: header_matches?(header_value),
        checked_at: Time.current
      }
    end

    # Either registered name counts: the controller accepts whichever arrives.
    def registered_header_value(payload)
      headers = payload["headers"].to_h

      headers.values_at(WhatsappApi::Client::AUTH_HEADER_NAME, "Authorization").compact.first.to_s
    end

    def header_matches?(header_value)
      return false if header_value.blank?

      ActiveSupport::SecurityUtils.secure_compare(header_value, ::Whatsapp.webhook_secret.to_s)
    end

    def expected_url
      @expected_url ||= "#{@expected_base_url.to_s.chomp("/")}#{::Whatsapp.webhook_path}"
    end

    def unreachable
      { reachable: false, expected_url: expected_url, checked_at: Time.current }
    end
end
