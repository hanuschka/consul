require_dependency Rails.root.join("app", "controllers", "users", "registrations_controller").to_s

class Users::RegistrationsController < Devise::RegistrationsController

  private

    def sign_up_params
      params[:user].delete(:redeemable_code) if params[:user].present? && params[:user][:redeemable_code].blank?
      params.require(:user).permit(:username, :email,
                                   :pfo_first_name, :pfo_last_name, :pfo_street_name, :pfo_street_number, :pfo_plz, :pfo_city,
                                   :gender, :date_of_birth,
                                   :password, :password_confirmation, :terms_of_service, :locale,
                                   :redeemable_code)
    end
end
