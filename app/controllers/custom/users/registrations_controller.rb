require_dependency Rails.root.join("app", "controllers", "users", "registrations_controller").to_s

class Users::RegistrationsController < Devise::RegistrationsController
  include HasRegisteredAddress

  # def create
  #   build_resource(sign_up_params)
  #   resource.registering_from_web = true
  #   process_temp_attributes_for(resource)

  #   if resource.valid?
  #     super
  #   else
  #     render :new
  #   end
  # end

  def user_info
    @user = User.new
    @user.use_redeemable_code = true if params[:use_redeemable_code].present?
  end

  def create_user
    @user = User.new(create_user_params)
    @user.username = Time.zone.now.strftime("%Y%^b%d%H%M%S%L")

    if @user.save
      set_flash_message! :notice, :signed_up_but_unconfirmed
      redirect_to users_sign_up_success_path
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

    if [params[:form_registered_address_city_id], params[:form_registered_address_street_id], params[:form_registered_address_id]].none? { |v| ["0", nil].include?(v) }
      @user.errors.add :registered_address_id, :blank
    end

    if update_user_details_params["date_of_birth(1i)"].blank? ||
         update_user_details_params["date_of_birth(2i)"].blank? ||
         update_user_details_params["date_of_birth(3i)"].blank?
      @user.errors.add :date_of_birth, :invalid
    end

    if @user.citizen?
      if RegisteredAddress::City.any?
        process_temp_attributes_for(@user)
      else
        @user.update(plz: @user.city_street.plz)
      end

      @user.errors.add :document_type, :blank if update_user_details_params[:document_type].blank?
      @user.errors.add :document_number, :blank if params[:user][:document_number].blank?
      @user.errors.add :document_number, :length unless params[:user][:document_number].length == 4

      if @user.first_name.present? &&
           @user.last_name.present? &&
           @user.date_of_birth.present? &&
           @user.plz.present? &&
           !@user.stamp_unique?
        @user.errors.add(:first_name, :uniqueness_check) unless @user.stamp_unique?
      end
    else
      @user.errors.add :plz, :blank if update_user_details_params[:plz].blank?
      @user.errors.add :plz, :format unless update_user_details_params[:plz] =~ /\A\d{5}\z/
      @user.errors.add :city_name, :blank if update_user_details_params[:city_name].blank?
      @user.errors.add :street_name, :blank if update_user_details_params[:street_name].blank?
      @user.errors.add :street_number, :blank if update_user_details_params[:street_number].blank?
    end

    if @user.errors.any?
      render :user_details
    elsif @user.citizen?
      @user.save
      Verifications::CreateXML.create_verification_request(current_user.id, params[:user][:document_number])
      redirect_to complete_user_registration_path
    else
      @user.save
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

  def sign_in_guest
    redirect_to root_path if current_user.present?

    @guest_user = User.new(guest: true)
  end

  def create_guest
    if current_user.present?
      redirect_to after_sign_in_path_for(current_user), notice: t("custom.devise_views.users.registrations.sign_in_guest.success")
    else
      guest_key = "guest_#{SecureRandom.uuid}"
      @guest_user = initialize_guest_user(guest_key)

      if @guest_user.save
        session[:guest_user_id] = guest_key
        redirect_to after_sign_in_path_for(@guest_user), notice: t("custom.devise_views.users.registrations.sign_in_guest.success")
      else
        render :sign_in_guest
      end
    end
  end

  def sign_out_guest
    session.delete(:guest_user_id)
    redirect_to root_path, notice: t("custom.devise_views.users.registrations.sign_out_guest.success")
  end

  private

    def create_user_params
      params[:user].delete(:redeemable_code) if params[:user].present? && params[:user][:redeemable_code].blank?
      params.require(:user).permit(:redeemable_code, :locale, :email, :password, :password_confirmation, :terms_of_service, :terms_data_storage, :terms_data_protection, :terms_general)
    end

    def update_user_details_params
      set_address_attributes

      params.require(:user).permit(
        :first_name, :last_name,
        :city_name, :plz, :street_name, :street_number, :street_number_extension,
        :registered_address_id,
        :date_of_birth,
        :document_type,
        :city_street_id,
        individual_group_value_ids: [])
    end

    def initialize_guest_user(guest_key)
      User.new(
        username: params[:user][:username],
        terms_data_protection: params[:user][:terms_data_protection],
        terms_general: params[:user][:terms_general],
        email: "#{guest_key}@example.com",
        guest: true,
        confirmed_at: Time.now.utc,
        skip_password_validation: true
      )
    end
end
