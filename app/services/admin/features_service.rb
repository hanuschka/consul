class Admin::FeaturesService < ApplicationService
  def call
    {
      ai:     ai_feature,
      matomo: matomo_feature
    }
  end

  private

  def matomo_feature
    secrets = Rails.application.secrets

    base_url = secrets.matomo_base_url.presence
    site_id  = secrets.matomo_site_id.presence

    {
      enabled:             Setting["feature.matomo"].present?,
      tracking_configured: base_url.present? && site_id.present?,
    }
  end

  def ai_feature
    {
      enabled: Ai::Settings.ai_available?,
      custom_client_token: custom_client_token?,
      ai_model: Ai::Settings.current_llm_model,
      ai_provider: Ai::Settings.current_llm_provider,
      custom_endpoint: custom_endpoint,
      projekt_import_tools: projekt_import_tools
    }
  end

  def custom_endpoint
    endpoint = Setting["ai.llm_api_endpoint"]

    {
      present: endpoint.present?,
      host: endpoint_host(endpoint)
    }
  end

  def endpoint_host(endpoint)
    return nil if endpoint.blank?

    parse_host(endpoint) || parse_host("//#{endpoint}")
  end

  def parse_host(value)
    URI.parse(value).host.presence
  rescue URI::InvalidURIError
    nil
  end

  def projekt_import_tools
    packages = ProjektImports::RequiredTools.packages_status

    {
      all_installed: packages.values.all? { |status| status[:installed] },
      packages: packages,
      missing_packages: packages.reject { |_package, status| status[:installed] }.keys
    }
  end

  def custom_client_token?
    case Ai::Settings.current_llm_provider
    when "bedrock"
      stored_value?("bedrock", "access_key_id")
    when "vertexai"
      stored_value?("vertexai", "project")
    when "ollama"
      false
    else
      stored_value?(Ai::Settings.current_llm_provider, "api_key")
    end
  end

  def stored_value?(service, name)
    ExternalApiKey.find_by(service: service, name: name)&.value.present?
  end
end
