require_dependency Rails.root.join("app", "controllers", "users", "registrations_controller").to_s

class Users::RegistrationsController < Devise::RegistrationsController

  private

    def sign_up_params
      params[:user].delete(:redeemable_code) if params[:user].present? && params[:user][:redeemable_code].blank?
      params.require(:user).permit(:username, :email,
                                   :dor_first_name, :dor_last_name, :dor_street_name, :dor_street_number, :dor_plz, :dor_city,
                                   :date_of_birth,
                                   :password, :password_confirmation, :terms_of_service, :locale,
                                   :redeemable_code)
    end
end
