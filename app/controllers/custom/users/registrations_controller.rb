require_dependency Rails.root.join("app", "controllers", "users", "registrations_controller").to_s

class Users::RegistrationsController < Devise::RegistrationsController
  http_basic_authenticate_with name: Rails.application.secrets.http_basic_username, password:  Rails.application.secrets.http_basic_password
  private

    def sign_up_params
      params[:user].delete(:redeemable_code) if params[:user].present? &&
                                                params[:user][:redeemable_code].blank?
      params.require(:user).permit(:username, :email,
                                   :first_name, :last_name, :city_street_id, :street_number, :plz, :city_name,
                                   :gender, :date_of_birth,
                                   :document_type, :document_last_digits,
                                   :password, :password_confirmation, :terms_of_service, :locale,
                                   :redeemable_code)
    end
end
