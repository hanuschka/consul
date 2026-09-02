class Adm::DeficiencyReports::StatusesController < Adm::DeficiencyReports::BaseController
  include Translatable

  def index
    authorize DeficiencyReport::Status, :index?,
      policy_class: Adm::DeficiencyReports::StatusPolicy

    @statuses = policy_scope(DeficiencyReport::Status, policy_scope_class: Adm::DeficiencyReports::StatusPolicy::Scope)

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.statuses"), icon: "flag" }]
  end

  def new
    @status = DeficiencyReport::Status.new
    authorize @status, policy_class: Adm::DeficiencyReports::StatusPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @status = DeficiencyReport::Status.find(params[:id])
    authorize @status, policy_class: Adm::DeficiencyReports::StatusPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @status = DeficiencyReport::Status.new(status_params)
    authorize @status, policy_class: Adm::DeficiencyReports::StatusPolicy

    if @status.save
      redirect_to adm_deficiency_reports_statuses_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.statuses.new.title"))
      render :new
    end
  end

  def update
    @status = DeficiencyReport::Status.find(params[:id])
    authorize @status, policy_class: Adm::DeficiencyReports::StatusPolicy

    if @status.update(status_params)
      redirect_to adm_deficiency_reports_statuses_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.statuses.edit.title"))
      render :edit
    end
  end

  def destroy
    @status = DeficiencyReport::Status.find(params[:id])
    authorize @status, policy_class: Adm::DeficiencyReports::StatusPolicy

    if @status.safe_to_destroy?
      @status.destroy!
      redirect_to adm_deficiency_reports_statuses_path, notice: t(".success")
    else
      redirect_to adm_deficiency_reports_statuses_path, alert: t(".cannot_destroy")
    end
  end

  def order_statuses
    authorize DeficiencyReport::Status, :update?, policy_class: Adm::DeficiencyReports::StatusPolicy
    DeficiencyReport::Status.order_statuses(params[:tree].map { |item| item[:id] })
    head :ok
  end

  private

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.deficiency_reports.statuses.index.title"), url: adm_deficiency_reports_statuses_path, icon: "flag" },
        { name: action_title }
      ]
    end

    def status_params
      params.require(:deficiency_report_status).permit(
        :title, :description, :color, :archive_reports, :icon, :notice_text, :reminder_delay
      )
    end
end
