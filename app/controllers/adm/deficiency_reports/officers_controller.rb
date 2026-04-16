class Adm::DeficiencyReports::OfficersController < Adm::DeficiencyReports::BaseController
  include Pagy::Backend

  def index
    authorize DeficiencyReport::Officer, policy_class: Adm::DeficiencyReports::OfficerPolicy

    @pagy, @officers = pagy(
      policy_scope(DeficiencyReport::Officer, policy_scope_class: Adm::DeficiencyReports::OfficerPolicy::Scope)
        .joins(:user)
        .order("users.username ASC")
    )

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.officers"), icon: "badge" }]
  end

  def search
    authorize DeficiencyReport::Officer, :create?, policy_class: Adm::DeficiencyReports::OfficerPolicy
    @user = User.find_by(email: params[:search])

    respond_to do |format|
      if @user
        @officer = DeficiencyReport::Officer.find_or_initialize_by(user: @user)
        format.turbo_stream
      else
        format.turbo_stream { render "user_not_found" }
      end
    end
  end

  def create
    @officer = DeficiencyReport::Officer.new(user_id: params[:user_id])
    authorize @officer, policy_class: Adm::DeficiencyReports::OfficerPolicy

    @officer.save!
    redirect_to adm_deficiency_reports_officers_path
  end

  def destroy
    @officer = DeficiencyReport::Officer.find(params[:id])
    authorize @officer, policy_class: Adm::DeficiencyReports::OfficerPolicy

    @officer.destroy!
    redirect_to adm_deficiency_reports_officers_path
  end

  def toggle_manage_all
    @officer = DeficiencyReport::Officer.find(params[:id])
    authorize @officer, :update?, policy_class: Adm::DeficiencyReports::OfficerPolicy

    @officer.update!(manage_all: !@officer.manage_all)
  end
end
