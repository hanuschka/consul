module Dt
  def self.url
    Rails.application.secrets.dt[:url]
  end

  def self.platforms_overview_url
    "#{url}/platforms"
  end

  def self.app_store_url
    "#{url}/apps"
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
    "https://demo.demokratie.today/bibliothek"
  end
end
