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
    unless session[:guest_user_id].present?
      guest_key = "guest_#{SecureRandom.uuid}"
      User.create_guest_user(guest_key)
      session[:guest_user_id] = guest_key
    end

    notice = t("custom.devise_views.users.registrations.sign_in_guest.success")
    flash[:notice] = notice

    unless request.headers["Referer"].include?(action_name)
      redirect_back(fallback_location: root_path)
    else
      redirect_to root_path
    end
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
                                   :terms_of_service, :terms_data_storage, :terms_data_protection, :terms_general,
                                   :locale,
                                   :redeemable_code,
                                   individual_group_value_ids: [])
    end
end
