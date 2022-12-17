require_dependency Rails.root.join("app", "controllers", "admin", "users_controller").to_s
class Admin::UsersController < Admin::BaseController
  load_and_authorize_resource

  has_filters %w[active erased outside_bam], only: :index

  def send_letter_verification_code
    @user = User.find(params[:id])
    @user.update!(bam_letter_verification_code_sent_at: Time.zone.now)
    respond_to do |format|
      format.js { render template: "admin/users/update_letter_verification_code_command" }
    end
  end

  def cancel_letter_verification_code
    @user = User.find(params[:id])
    @user.update!(bam_letter_verification_code_sent_at: nil)
    respond_to do |format|
      format.js { render template: "admin/users/update_letter_verification_code_command" }
    end
  end

  def verify
    @user = User.find(params[:id])
    @user.take_votes_from_erased_user
    geozone = Geozone.find_with_plz(@user.plz)
    @user.update!(verified_at: Time.current, geozone: geozone)

    Mailer.manual_verification_confirmation(@user).deliver_later
  end

  def unverify
    @user = User.find(params[:id])
    @user.take_votes_from_erased_user
    @user.update!(verified_at: nil, geozone: nil)
  end
end
