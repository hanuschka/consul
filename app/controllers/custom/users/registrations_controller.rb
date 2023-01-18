require_dependency Rails.root.join("app", "controllers", "users", "registrations_controller").to_s

class Users::RegistrationsController < Devise::RegistrationsController
  prepend_before_action :authenticate_scope!, only: [:edit, :update, :destroy, :finish_signup, :do_finish_signup, :user_location, :update_location, :user_details, :update_details, :complete, :complete_code, :user_verification_code, :update_user_verification_code]

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
    @user.update!(update_user_details_params)

    @user.errors.add :first_name, :blank if update_user_details_params[:first_name].blank?
    @user.errors.add :last_name, :blank if update_user_details_params[:last_name].blank?
    @user.errors.add :date_of_birth, :blank if update_user_details_params['date_of_birth(1i)'].blank?
    @user.errors.add :date_of_birth, :blank if update_user_details_params['date_of_birth(2i)'].blank?
    @user.errors.add :date_of_birth, :blank if update_user_details_params['date_of_birth(3i)'].blank?
    @user.errors[:date_of_birth].uniq! if @user.errors[:date_of_birth].any?

    if @user.citizen?

      if update_user_details_params[:city_street_id].blank?
        @user.errors.add :city_street_id, :blank
      else
        @user.update(plz: @user.city_street.plz)
      end

      @user.errors.add :document_type, :blank if update_user_details_params[:document_type].blank?
      @user.errors.add :document_number, :blank if params[:user][:document_number].blank?
      @user.errors.add :document_number, :length unless params[:user][:document_number].length == 4

      @user.errors.add(:first_name, :uniqueness_check) unless @user.stamp_unique?
    else
      @user.errors.add :plz, :blank if update_user_details_params[:plz].blank?
      @user.errors.add :plz, :format unless update_user_details_params[:plz] =~ /\A\d{5}\z/
      @user.errors.add :city_name, :blank if update_user_details_params[:city_name].blank?
      @user.errors.add :street_name, :blank if update_user_details_params[:street_name].blank?
      @user.errors.add :house_number, :blank if update_user_details_params[:house_number].blank?
    end

    if @user.errors.any?
      render :user_details
    elsif @user.citizen?
      Verifications::CreateXML.create_verification_request(current_user.id, params[:user][:document_number])
      redirect_to complete_user_registration_path
    else
      @user.update(bam_letter_verification_code: rand(11111111..99999999)) unless @user.bam_letter_verification_code.present?
      Verifications::CreateXML.create_verification_letter(current_user)
      redirect_to complete_user_registration_code_path
    end
  end
  
  def complete
  end

  def complete_code
  end

  def user_verification_code
    @user = current_user
  end

  def check_user_verification_code
    @user = current_user
    if params[:user] &&
        params[:user][:bam_letter_verification_code] &&
        params[:user][:bam_letter_verification_code].to_i == @user.bam_letter_verification_code

      current_user.update( verified_at: Time.now )
      redirect_to root_path, notice: t('custom.sign_up.check_user_verification_code.user_verified')
    else
      @user.errors.add(:bam_letter_verification_code, :not_valid)
      render :user_verification_code
    end
  end

  private

  def create_user_params
    params[:user].delete(:redeemable_code) if params[:user].present? && params[:user][:redeemable_code].blank?
    params.require(:user).permit(:redeemable_code, :locale, :email, :password, :password_confirmation, :terms_of_service)
  end

  def update_user_details_params
    params.require(:user).permit(:first_name, :last_name, :plz, :"date_of_birth(1i)", :"date_of_birth(2i)", :"date_of_birth(3i)", :document_type, :street_name, :house_number, :city_name, :city_street_id)
  end
end
