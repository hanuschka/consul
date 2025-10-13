module Dt
  def self.url
    domain = Rails.application.secrets.dt[:domain]

    if Rails.env.development? && Rails.application.secrets.dt[:dont_use_https_on_dev]
      port = Rails.application.secrets.dt[:port]

      "http://#{domain}:#{port}"
    else
      "https://#{domain}"
    end
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
end
