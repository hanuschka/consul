class Admin::AiFeaturesService < ApplicationService
  def call
    {
      enabled: Ai::Settings.ai_available?,
      custom_client_token: custom_client_token?,
      ai_model: Ai::Settings.current_llm_model,
      ai_provider: Ai::Settings.current_llm_provider,
      custom_endpoint: custom_endpoint,
      projekt_import_tools: projekt_import_tools,
      headless_browser_libraries: headless_browser_libraries,
      image_ai_marking: image_ai_marking
    }
  end

  private

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

  def headless_browser_libraries
    if !HeadlessBrowser::RequiredLibraries.supported?
      return {
        supported: false,
        all_installed: nil,
        packages: {},
        missing_packages: [],
        install_command: HeadlessBrowser::RequiredLibraries::INSTALL_COMMAND
      }
    end

    packages = HeadlessBrowser::RequiredLibraries.packages_status
    missing_packages = packages.reject { |_package, status| status[:installed] }.keys

    {
      supported: true,
      all_installed: missing_packages.empty?,
      packages: packages,
      missing_packages: missing_packages,
      install_command: HeadlessBrowser::RequiredLibraries::INSTALL_COMMAND
    }
  end

  # Marking generated images is mandatory, so a box without exiftool cannot
  # generate AI images at all -- unlike the other tool checks here, this one
  # reports a hard outage rather than a degraded feature.
  def image_ai_marking
    {
      status: ::ExiftoolCommand.runtime_status,
      binary_path: ::ExiftoolCommand.binary_path,
      all_installed: ::ExiftoolCommand.available?,
      install_command: ::ExiftoolCommand::INSTALL_COMMAND
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
