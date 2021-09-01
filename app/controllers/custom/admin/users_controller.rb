require_dependency Rails.root.join("app", "controllers", "admin", "users_controller").to_s
class Admin::UsersController < Admin::BaseController
  load_and_authorize_resource

  has_filters %w[active erased outside_bam], only: :index

  def send_letter_verification_code
    @user = User.find(params[:id])
    @user.update(bam_letter_verification_code_sent_at: Time.now)
    respond_to do |format|
      format.js { render template: "admin/users/update_letter_verification_code_command" }
    end
	end

	def cancel_letter_verification_code
    @user = User.find(params[:id])
    @user.update(bam_letter_verification_code_sent_at: nil)
    respond_to do |format|
      format.js { render template: "admin/users/update_letter_verification_code_command" }
    end
	end
end
