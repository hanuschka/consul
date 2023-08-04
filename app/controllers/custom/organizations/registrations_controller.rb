require_dependency Rails.root.join("app", "controllers", "organizations", "registrations_controller").to_s

class Organizations::RegistrationsController < Devise::RegistrationsController
  def new
    redirect_to new_user_registration_path
  end

  private

    def allowed_params
      [
        :email, :password, :phone_number, :password_confirmation,
        :terms_of_service, :terms_data_storage, :terms_data_protection, :terms_general,
        organization_attributes: [:name, :responsible_name]
      ]
    end
end
