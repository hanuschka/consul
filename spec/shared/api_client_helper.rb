module ApiClientHelper
  def create_api_client(attributes = {})
    default_attributes = {
      name: 'Test Client',
      service_user_email: "test_client_#{SecureRandom.hex(4)}@example.com",
      registration_status: :registered,
      access_level: :admin
    }
    
    ApiClient.create!(default_attributes.merge(attributes)).tap(&:reload)
  end
end

