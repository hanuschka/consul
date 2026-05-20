module Dt
  def self.url
    return if domain.blank?

    if Rails.env.development?
      port = Rails.application.secrets.dt[:port]

      "http://#{domain}:#{port}"
    else
      "https://#{domain}"
    end
  end

  def self.domain
    Rails.application.secrets.dt[:domain]
  end

  def self.enabled?
    Rails.application.secrets.dt[:enabled]
  end

  def self.connected?
    InternalApiClient.dt_connected?
  end

  def self.platforms_overview_url
    "#{url}/platforms"
  end

  def self.app_store_url
    "#{url}/apps"
  end

  def self.navigate_to_app_url(codename)
    "#{url}/apps/navigate/#{codename}"
  end

  def self.ticket_system_url
    "https://demokratie.atlassian.net/servicedesk/customer/portal/4/group/15"
  end

  def self.meetups_url
    "https://www.eventbrite.de/e/consul-meetup-demokratietoday-registrierung-339994872817"
  end

  def self.newsletter_url
    "https://demokratie.today/#newsletter"
  end

  def self.demo_url
    "https://demo.demokratie.today/bibliothek"
  end

  def self.website_url
    "https://demokratie.today"
  end

  def self.file_import_url(user_id:)
    return nil if !connected?

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.secret_key_base,
      digest: "SHA256"
    )

    token = verifier.generate(
      { "user_id" => user_id, "exp" => 5.minutes.from_now.to_i },
      purpose: :iframe_auth
    )

    "#{url}/projekt_imports/from_file/new?embedded=true&iframe_token=#{CGI.escape(token)}"
  end
end
