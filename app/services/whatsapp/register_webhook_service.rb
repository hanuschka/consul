class Whatsapp::RegisterWebhookService < ApplicationService
  def initialize(base_url: nil)
    @base_url = base_url
  end

  def call
    return if !::Whatsapp.configured?
    return if webhook_url.blank?

    response = WhatsappApi::Client.new.webhooks.configure(
      url: webhook_url,
      headers: { WhatsappApi::Client::AUTH_HEADER_NAME => ::Whatsapp.webhook_secret }
    )

    log(response)

    response
  end

  private

    def webhook_url
      @webhook_url ||=
        if host_url.blank?
          nil
        else
          "#{host_url}#{Rails.application.routes.url_helpers.whatsapp_api_webhook_path}"
        end
    end

    def host_url
      @base_url.presence || Setting["url"].presence&.chomp("/") || url_options_host
    end

    def url_options_host
      options = UrlOptions.default.to_h

      return if options[:host].blank?

      "#{options[:protocol].presence || 'https'}://#{options[:host]}"
    end

    def log(response)
      if response.success?
        Rails.logger.info("[Whatsapp] webhook registered at #{webhook_url}")
      else
        Rails.logger.error("[Whatsapp] webhook registration failed: #{response.code}")
      end
    end
end
