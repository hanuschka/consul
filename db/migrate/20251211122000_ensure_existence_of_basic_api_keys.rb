class EnsureExistenceOfBasicApiKeys < ActiveRecord::Migration[6.1]
  def up
    ExternalApiKey::KEYS_DATA.each do |key_data|
      ExternalApiKey.find_or_create_by(service: key_data[:service], name: key_data[:name])
    end
  end

  def down
  end
end
