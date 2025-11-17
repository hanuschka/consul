class Admin::AiSettings::ApiKeyComponent < ApplicationComponent
  attr_reader :key_name

  def initialize(key_name)
    @key_name = key_name
  end

  def api_key
    @api_key ||= ExternalApiKey.find_or_initialize_by(name: key_name)
  end
end
