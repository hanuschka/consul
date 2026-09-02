require_dependency Rails.root.join("app", "controllers", "users", "registrations_controller").to_s

class Users::RegistrationsController < Devise::RegistrationsController
  include HasRegisteredAddress

  def create
    build_resource(sign_up_params)
    resource.registering_from_web = true
    resource.newsletter_chosen = params[:user][:newsletter].present? if params[:user].present?
    process_temp_attributes_for(resource)

    resource_valid = resource.valid?
    unconfirmed_user = unconfirmed_user_with_same_email

    if unconfirmed_user.present?
      unconfirmed_user.resend_confirmation_instructions

      redirect_to new_user_registration_path,
        notice: t("custom.devise_views.users.registrations.create.email_taken_by_unconfirmed_account")
    elsif resource_valid
      new_unique_stamp = resource.prepare_unique_stamp
      existing_user_with_same_stamp = User.find_by(unique_stamp: new_unique_stamp) if new_unique_stamp.present?

      if new_unique_stamp.present? && existing_user_with_same_stamp.present?
        Mailer.existing_stamp_notify_existing_user(existing_user_with_same_stamp).deliver_later
        Mailer.existing_stamp_notify_new_user(resource.email).deliver_later

        redirect_to new_user_registration_path,
          alert: t("custom.devise_views.users.registrations.create.existing_user_with_same_stamp")
      else
        super
      end
    else
      render :new
    end
  end

  def sign_in_guest
    redirect_to root_path if current_user.present?

    store_location_for(:user, CGI::unescape(params[:intended_path])) if params[:intended_path].present?
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

  protected

    def after_sign_up_path_for(resource)
      case pending_invitation&.role_type
      when nil
        super
      when "ProjektManager"
        adm_projekts_root_path
      else
        adm_root_path
      end
    end

    def build_resource(hash = {})
      super
      resource.skip_confirmation! if pending_invitation.present?
    end

  private

    def unconfirmed_user_with_same_email
      email = resource.email.to_s.strip.downcase
      return if email.blank?

      user = User.find_by(email: email)
      user if user.present? && !user.confirmed?
    end

    def pending_invitation
      return @pending_invitation if defined?(@pending_invitation)

      token = params[:invitation_token]
      return @pending_invitation = nil if token.blank?

      pending = PendingRoleAssignment.find_by_invitation_token(token)
      return @pending_invitation = nil if pending.nil?

      email = params.dig(:user, :email)&.strip&.downcase
      return @pending_invitation = nil if email != pending.email

      @pending_invitation = pending
    end

    def sign_up_params
      set_address_attributes

      params[:user].delete(:redeemable_code) if params[:user].present? &&
                                                params[:user][:redeemable_code].blank?

      params.require(:user).permit(:username, :email,
                                   :first_name, :last_name,
                                   :city_name, :plz, :street_name, :street_number, :street_number_extension,
                                   :registered_address_id,
                                   :gender, :date_of_birth,
                                   :document_type, :document_last_digits,
                                   :password, :password_confirmation,
                                   :newsletter,
                                   :terms_of_service, :terms_data_storage, :terms_data_protection, :terms_general,
                                   :locale,
                                   :redeemable_code,
                                   individual_group_value_ids: [])
    end
end
