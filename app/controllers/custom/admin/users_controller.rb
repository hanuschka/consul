require_dependency Rails.root.join("app", "controllers", "admin", "users_controller").to_s

class Admin::UsersController < Admin::BaseController
  include HasRegisteredAddress

  def index
    @users = @users.not_guests.send(@current_filter).order_filter(params)
    @users = @users.by_username_email_or_document_number(params[:search]) if params[:search]

    unless params[:format] == "csv"
      if @users.is_a?(Array)
        @users = Kaminari.paginate_array(@users).page(params[:page])
      else
        @users = @users.page(params[:page])
      end
    end

    respond_to do |format|
      format.html
      format.js
      format.csv do
        CsvJobs::UsersJob.perform_later(current_user.id, @users.pluck(:id))
        redirect_to admin_users_path, notice: "Export wird vorbereitet. Du erhältst eine E-Mail, sobald der Export fertig ist."
      end
    end
  end

  def show
    @user = User.find(params[:id])
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find_by(id: params[:id])
    process_temp_attributes_for(@user)

    if @user.update(user_params)
      if params[:reverify].present?
        @user.reverify!
        @user.update!(reverify: true)
      end
      redirect_to admin_users_path, notice: "Benutzer aktualisiert"
    else
      render :edit
    end
  end

  def verify
    @user = User.find(params[:id])
    if @user.verify!
      @user.update!(reverify: false)
      @verification_result_notice = "Benutzer verifiziert"
      Mailer.manual_verification_confirmation(@user).deliver_later
    else
      @verification_result_notice = "Benutzer konnte nicht verifiziert werden"
    end
  end

  def unverify
    @user = User.find(params[:id])
    @user.unverify!
    @user.update!(reverify: false)
  end

  def reverify
    return if Setting["feature.melderegister"].blank?

    VerificationServices::UsersReverifier.call
    redirect_to admin_users_path, notice: t("custom.admin.users.reverify_success_notice")
  end

  private

    def user_params
      set_address_attributes

      params.require(:user).permit(:email,
                                   :first_name, :last_name,
                                   :city_name, :plz, :street_name, :street_number, :street_number_extension,
                                   :registered_address_id,
                                   :gender, :date_of_birth)
                                   # :document_type, :document_last_digits,
                                   # :password, :password_confirmation)
    end
end
