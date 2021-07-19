require_dependency Rails.root.join("app", "controllers", "users", "registrations_controller").to_s

class Users::RegistrationsController < Devise::RegistrationsController
  prepend_before_action :authenticate_scope!, only: [:edit, :update, :destroy, :finish_signup, :do_finish_signup, :details, :update_details, :complete]

  def new
  end

  def personal
    resource = build_resource
    resource.use_redeemable_code = true if params[:use_redeemable_code].present?
  end

  def create
    build_resource(sign_up_params)
    if resource.valid?
      resource.save
      if resource.persisted?
        if resource.active_for_authentication?
					set_flash_message! :notice, :signed_up_but_unconfirmed
					redirect_to users_sign_up_success_path
				else
          set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
          expire_data_after_sign_in!
          respond_with resource, location: after_inactive_sign_up_path_for(resource)
				end
      else
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
      end
    else
      render :personal
    end
  end

  def details
    @user = current_user
  end

  def update_details
    @user = current_user

    if @user.update(update_details_params)
      redirect_to users_sign_up_complete_path
		else
      render :details
		end
  end
  
  def complete
  end

  private

	def update_details_params
		params.require(:user).permit(:first_name, :last_name, :plz, :"date_of_birth(1i)", :"date_of_birth(2i)", :"date_of_birth(3i)", :document_type, :document_number)
	end
end
