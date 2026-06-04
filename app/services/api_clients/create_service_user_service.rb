class ApiClients::CreateServiceUserService < ApplicationService
  def initialize(api_client:, user_attributes: {})
    @api_client = api_client
    @user_attributes = user_attributes
  end

  def call
    user = api_client.build_user(default_attributes.merge(profile_attributes))

    if user.username.blank?
      user.username = generate_username
    end

    user.save!

    user
  end

  private

    attr_reader :api_client, :user_attributes

    def default_attributes
      {
        email: api_client.service_user_email,
        password: SecureRandom.hex(32),
        confirmed_at: Time.current,
        terms_data_storage: "1",
        terms_data_protection: "1",
        terms_general: "1",
        skip_password_validation: true
      }
    end

    def profile_attributes
      user_attributes.to_h.symbolize_keys
    end

    def generate_username
      base_username = "#{api_client.name}_service".parameterize.underscore
      username = base_username
      counter = 1

      while User.exists?(username: username)
        username = "#{base_username}_#{counter}"
        counter += 1
      end

      username
    end
end
