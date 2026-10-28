load Rails.root.join("app", "controllers", "organizations", "registrations_controller.rb")

class Organizations::RegistrationsController < Devise::RegistrationsController
  private

    def allowed_params
      [
        :email, :password, :phone_number, :password_confirmation,
        :terms_of_service, :terms_data_storage, :terms_data_protection, :terms_general,
        organization_attributes: [:name, :responsible_name]
      ]
    end
end
