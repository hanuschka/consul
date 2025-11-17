class ExternalApiKey < ApplicationRecord
  def self.service_links
    {
      matomo: "https://matomo.org",
      mapbox: "https://www.mapbox.com",
      vcs: "https://vc.systems",
      openai: "https://platform.openai.com",
      brevo: "https://www.brevo.com"
    }
  end

  def service_link
    self.class.service_links[name.to_sym]
  end
end
