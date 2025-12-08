class Admin::AiSettings::ApiKeyComponent < ApplicationComponent
  attr_reader :key_name, :service

  def initialize(key_name, service)
    @key_name = key_name
    @service = service
  end

  def api_key
    @api_key ||= ExternalApiKey.find_or_create_by(name: key_name, service: service)
  end
end
