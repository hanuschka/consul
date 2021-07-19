require_dependency Rails.root.join("app", "controllers", "users", "confirmations_controller").to_s

class Users::ConfirmationsController < Devise::ConfirmationsController

  # GET /resource/confirmation?confirmation_token=abcdef
  def show
    # In the default implementation, this already confirms the resource:
    # self.resource = self.resource = resource_class.confirm_by_token(params[:confirmation_token])
    self.resource = resource_class.find_by!(confirmation_token: params[:confirmation_token])

    yield resource if block_given?

    # New condition added to if: when no password was given, display the "show" view (which uses "update" above)
    if resource.encrypted_password.blank?
      respond_with_navigational(resource) { render :show }
    elsif resource.errors.empty?
      set_official_position if resource.has_official_email?
      resource.confirm # Last change: confirm happens here for people with passwords instead of af the top of the show action
      set_flash_message(:notice, :email_confirmed) if is_flashing_format?
      sign_in(resource)
      redirect_to users_sign_up_details_path
    else
      respond_with_navigational(resource.errors, status: :unprocessable_entity) { render :new }
    end
  end
end
