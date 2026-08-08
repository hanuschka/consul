class Whatsapp::Platform::RegisterWebhookService < ApplicationService
  def initialize(base_url: nil)
    @base_url = base_url
  end

  def call
    return if !::Whatsapp.configured?
    return if webhook_url.blank?

    response = WhatsappApi::Client.new.webhooks.configure(
      url: webhook_url,
      headers: auth_headers
    )

    log(response)

    response
  end

  private

    # Registered under both names because 360dialog accepts either and there is
    # no way to tell in advance which one it will send back to us.
    def auth_headers
      {
        WhatsappApi::Client::AUTH_HEADER_NAME => ::Whatsapp.webhook_secret,
        "Authorization" => ::Whatsapp.webhook_secret
      }
    end

    def webhook_url
      @webhook_url ||=
        if host_url.blank?
          nil
        else
          "#{host_url}#{::Whatsapp.webhook_path}"
        end
    end

    def host_url
      @base_url.presence || ::Setting["url"].presence&.chomp("/") || url_options_host
    end

    def url_options_host
      options = ::UrlOptions.default.to_h

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
