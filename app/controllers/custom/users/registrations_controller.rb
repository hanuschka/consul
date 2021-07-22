require_dependency Rails.root.join("app", "controllers", "users", "registrations_controller").to_s

class Users::RegistrationsController < Devise::RegistrationsController
  prepend_before_action :authenticate_scope!, only: [:edit, :update, :destroy, :finish_signup, :do_finish_signup, :details, :update_details, :complete]

  def user_info
    @user = User.new
    @user.use_redeemable_code = true if params[:use_redeemable_code].present?
  end

  def create_user
    @user = User.new(create_user_params)
    @user.username = Time.now.strftime("%Y%^b%d%H%M%S%L")

    if @user.valid?
      @user.save

      if @user.persisted?
        if @user.active_for_authentication?
          set_flash_message! :notice, :signed_up_but_unconfirmed
          redirect_to users_sign_up_success_path
        else
          set_flash_message! :notice, :"signed_up_but_#{@user.inactive_message}"
          expire_data_after_sign_in!
          respond_with @user, location: after_inactive_sign_up_path_for(@user)
        end
      else
        clean_up_passwords @user
        set_minimum_password_length
        respond_with @user
      end

    else
      render :user_info
    end
  end

  def user_location
    @user = current_user
  end

  def update_location
    @user = current_user
    if params[:user] && params[:user][:location] && @user.update(location: params[:user][:location])
      redirect_to collect_user_details_path
    else
      @user.errors.add(:location, :blank)
      render :user_location
    end
  end

  def user_details
    @user = current_user
  end

  def update_details
    @user = current_user

    if @user.update(update_user_details_params.except(:document_number, :document_type)) && @user.citizen?
      Verifications::CreateXML.create_verification_request(current_user.id, update_user_details_params[:document_type], update_user_details_params[:document_number] )
      redirect_to complete_user_registration_path
    elsif @user.update(update_user_details_params.except(:document_number, :document_type))
      Verifications::CreateXML.create_verification_letter(current_user.id)
      redirect_to complete_user_registration_path
    else
      render :user_details
    end
  end
  
  def complete
  end

  private

  def create_user_params
    params[:user].delete(:redeemable_code) if params[:user].present? && params[:user][:redeemable_code].blank?
    params.require(:user).permit(:redeemable_code, :locale, :email, :password, :password_confirmation, :terms_of_service)
  end

  def update_user_details_params
    params.require(:user).permit(:first_name, :last_name, :plz, :"date_of_birth(1i)", :"date_of_birth(2i)", :"date_of_birth(3i)", :document_type, :document_number)
  end
end
