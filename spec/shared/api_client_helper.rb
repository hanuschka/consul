module ApiClientHelper
  def create_api_client(attributes = {})
    default_attributes = {
      name: 'Test Client',
      service_user_email: "test_client_#{SecureRandom.hex(4)}@example.com",
      access_level: :admin,
      use_system_user: false
    }

    api_client = ApiClient.create!(default_attributes.merge(attributes))

    if api_client.dedicated_user_mode?
      ApiClients::CreateServiceUserService.call(api_client: api_client)
    end

    api_client.tap(&:reload)
  end
end

