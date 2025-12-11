class ExternalApiKey < ApplicationRecord
  KEYS_DATA = [
    { service: "matomo", name: "access_token"},
    { service: "mapbox", name: "public_token"},
    { service: "openai", name: "api_key"}
  ]

  validates :service, presence: true
  validates :name, presence: true
  validates :service, uniqueness: true

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
    sym = service&.to_sym

    self.class.service_links[service] || ""
  end

  def self.matomo_token
    get_api_key_or_default(
      "matomo",
      "access_token",
      Rails.application.secrets.dig(:matomo, :access_token)
    )
  end

  def self.mapbox_public_token
    get_api_key_or_default(
      "mapbox",
      "public_token",
      Rails.application.secrets.dig(:mapbox, :public_token)
    )
  end

  # def self.vcs_token
  #   get_api_key_or_default(
  #     "vcs",
  #     Rails.application.secrets.dig(:vcs, :token)
  #   )
  # end

  def self.openai_token
    get_api_key_or_default(
      "openai",
      "api_key",
      Rails.application.secrets.dig(:ai, :openai_api_key)
    )
  end


  def self.get_api_key_or_default(service, name, default_api_key = nil)
    api_key = find_by(service: service, name: name)&.value

    api_key.presence || default_api_key
  end
end
