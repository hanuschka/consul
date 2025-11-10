class Users::PasswordsController < Devise::PasswordsController
  def create
    user = User.find_by(email: resource_params[:email])

    if user.present? && !user.confirmed?
      self.resource = resource_class.send_confirmation_instructions(resource_params)
    else
      self.resource = resource_class.send_reset_password_instructions(resource_params)
    end

    yield resource if block_given?

    if successfully_sent?(resource)
      respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
    else
      respond_with(resource)
    end
  end
end
