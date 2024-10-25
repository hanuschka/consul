class DeficiencyReportManagement::OfficersController < DeficiencyReportManagement::BaseController
  load_and_authorize_resource :officer, class: "DeficiencyReport::Officer", except: [:edit, :show]

  def index
    @officers = DeficiencyReport::Officer.all.page(params[:page])
  end

  def search
    @user = User.find_by(email: params[:search])

    respond_to do |format|
      if @user
        @officer = DeficiencyReport::Officer.find_or_initialize_by(user: @user)
        format.js
      else
        format.js { render 'user_not_found' }
      end
    end
  end

  def create
    @officer.user_id = params[:user_id]
    @officer.save!

    redirect_to deficiency_report_management_officers_path
  end

  def destroy
    @officer.destroy!
    redirect_to deficiency_report_management_officers_path
  end
end
