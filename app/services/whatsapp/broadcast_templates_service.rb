class Whatsapp::BroadcastTemplatesService < ApplicationService
  APPROVED_STATUS = "approved".freeze

  def call
    return [] if !::Whatsapp.configured?

    response = WhatsappApi::Client.new.templates.index

    return [] if !response.success?

    build_list(response.parsed_response.to_h)
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] template list failed: #{e.class} - #{e.message}")

    []
  end

  private

    def build_list(payload)
      Array(payload["waba_templates"] || payload["data"]).map do |template|
        {
          name: template["name"].to_s,
          language: template["language"].to_s,
          status: template["status"].to_s.downcase,
          approved: template["status"].to_s.downcase == APPROVED_STATUS,
          category: template["category"].to_s
        }
      end
    end
end
