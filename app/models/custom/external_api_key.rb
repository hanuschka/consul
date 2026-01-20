class ExternalApiKey < ApplicationRecord
  KEYS_DATA = [
    { service: "matomo", name: "access_token"},
    { service: "mapbox", name: "public_token"},
    { service: "openai", name: "api_key"}
  ]

  validates :service, presence: true, uniqueness: true
  validates :name, presence: true

  def self.service_links
    {
      matomo: "https://matomo.org",
      mapbox: "https://www.mapbox.com",
      vcs: "https://vc.systems",
      openai: "https://platform.openai.com",
      anthropic: "https://console.anthropic.com",
      gemini: "https://aistudio.google.com",
      deepseek: "https://platform.deepseek.com",
      mistral: "https://console.mistral.ai",
      openrouter: "https://openrouter.ai",
      perplexity: "https://www.perplexity.ai",
      gpustack: "https://gpustack.ai",
      bedrock: "https://aws.amazon.com/bedrock",
      vertex_ai: "https://cloud.google.com/vertex-ai",
      brevo: "https://www.brevo.com"
    }
  end

  def service_link
    sym = service&.to_sym

    self.class.service_links[service] || ""
  end

  def self.matomo_access_token
    get_api_key_or_default(
      "matomo",
      "access_token",
      Rails.application.secrets.fetch(:matomo_access_token, '')
    )
  end

  def self.mapbox_public_token
    get_api_key_or_default(
      "mapbox",
      "public_token",
      Rails.application.secrets.dig(:mapbox, :public_token)
    )
  end

  def self.openai_api_key
    get_api_key_or_default(
      "openai",
      "api_key",
      Rails.application.secrets.dig(:ai, :openai_api_key)
    )
  end

  def self.anthropic_api_key
    get_api_key_or_default(
      "anthropic",
      "api_key",
      Rails.application.secrets.dig(:ai, :anthropic_api_key)
    )
  end

  def self.gemini_api_key
    get_api_key_or_default(
      "gemini",
      "api_key",
      Rails.application.secrets.dig(:ai, :gemini_api_key)
    )
  end

  def self.deepseek_api_key
    get_api_key_or_default(
      "deepseek",
      "api_key",
      Rails.application.secrets.dig(:ai, :deepseek_api_key)
    )
  end

  def self.mistral_api_key
    get_api_key_or_default(
      "mistral",
      "api_key",
      Rails.application.secrets.dig(:ai, :mistral_api_key)
    )
  end

  def self.openrouter_api_key
    get_api_key_or_default(
      "openrouter",
      "api_key",
      Rails.application.secrets.dig(:ai, :openrouter_api_key)
    )
  end

  def self.perplexity_api_key
    get_api_key_or_default(
      "perplexity",
      "api_key",
      Rails.application.secrets.dig(:ai, :perplexity_api_key)
    )
  end

  def self.gpustack_api_key
    get_api_key_or_default(
      "gpustack",
      "api_key",
      Rails.application.secrets.dig(:ai, :gpustack_api_key)
    )
  end

  def self.bedrock_access_key_id
    get_api_key_or_default(
      "bedrock",
      "access_key_id",
      Rails.application.secrets.dig(:ai, :bedrock_access_key_id)
    )
  end

  def self.bedrock_secret_access_key
    get_api_key_or_default(
      "bedrock",
      "secret_access_key",
      Rails.application.secrets.dig(:ai, :bedrock_secret_access_key)
    )
  end

  def self.bedrock_region
    get_api_key_or_default(
      "bedrock",
      "region",
      Rails.application.secrets.dig(:ai, :bedrock_region)
    )
  end

  def self.vertex_ai_project
    get_api_key_or_default(
      "vertex_ai",
      "project",
      Rails.application.secrets.dig(:ai, :vertex_ai_project)
    )
  end

  def self.vertex_ai_credentials
    get_api_key_or_default(
      "vertex_ai",
      "credentials",
      Rails.application.secrets.dig(:ai, :vertex_ai_credentials)
    )
  end

  def self.ensure_existence_of_api_keys
    ExternalApiKey::KEYS_DATA.each do |key_data|
      ExternalApiKey.find_or_create_by(service: key_data[:service], name: key_data[:name])
    end
  end

  def self.get_api_key_or_default(service, name, default_api_key = nil)
    api_key = find_by(service: service, name: name)&.value

    api_key.presence || default_api_key
  end
end
