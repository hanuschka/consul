require_dependency Rails.root.join("app", "controllers", "users", "registrations_controller").to_s

class Users::RegistrationsController < Devise::RegistrationsController
  include HasRegisteredAddress

  def create
    build_resource(sign_up_params)
    resource.registering_from_web = true
    process_temp_attributes_for(resource)

    if resource.valid?
      super
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

  private

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
                                   :newsletter, :terms_of_service, :terms_data_storage, :terms_data_protection, :terms_general,
                                   :locale,
                                   :redeemable_code,
                                   individual_group_value_ids: [])
    end
end
