require_dependency Rails.root.join("app", "controllers", "admin", "users_controller").to_s

class Admin::UsersController < Admin::BaseController
  has_filters %w[active erased outside_bam], only: :index

  def index
    @users = @users.send(@current_filter).order(:created_at)
    @users = @users.by_username_email_or_document_number(params[:search]) if params[:search]
    @users = @users.page(params[:page]) unless params[:format] == "csv"
    respond_to do |format|
      format.html
      format.js
      format.csv do
        send_data CsvServices::UsersExporter.call(@users), filename: "users-#{Time.zone.today}.csv"
      end
    end
  end

  def verify
    @user = User.find(params[:id])
    if @user.verify!
      @verification_result_notice = "Benutzer verifiziert"
      Mailer.manual_verification_confirmation(@user).deliver_later
    else
      @verification_result_notice = "Benutzer konnte nicht verifiziert werden"
    end
  end

  def unverify
    @user = User.find(params[:id])
    @user.update!(verified_at: nil, geozone: nil, unique_stamp: nil)
  end

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
end
