class Adm::DeficiencyReports::ReportProfilesController < Adm::DeficiencyReports::BaseController
  before_action :load_report_profile, only: [:show, :edit, :update, :destroy, :pause, :resume, :generate]
  before_action :load_form_options, only: [:new, :edit, :create, :update]

  def index
    authorize DeficiencyReport::ReportProfile, :index?,
      policy_class: Adm::DeficiencyReports::ReportProfilePolicy

    @report_profiles = policy_scope(DeficiencyReport::ReportProfile, policy_scope_class: Adm::DeficiencyReports::ReportProfilePolicy::Scope)
                         .order(:name)

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.report_profiles"), icon: "summarize" }]
  end

  def show
    authorize @report_profile, policy_class: Adm::DeficiencyReports::ReportProfilePolicy

    @pagy, @management_reports = pagy(@report_profile.management_reports.newest_first)

    @breadcrumbs = breadcrumbs_for_action(@report_profile.name)
  end

  def new
    @report_profile = DeficiencyReport::ReportProfile.new(
      building_blocks: DeficiencyReport::ReportProfile::BUILDING_BLOCKS, weekday: 1
    )
    authorize @report_profile, policy_class: Adm::DeficiencyReports::ReportProfilePolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    authorize @report_profile, policy_class: Adm::DeficiencyReports::ReportProfilePolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @report_profile = DeficiencyReport::ReportProfile.new(report_profile_params)
    authorize @report_profile, policy_class: Adm::DeficiencyReports::ReportProfilePolicy

    if @report_profile.save
      redirect_to adm_deficiency_reports_report_profiles_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.report_profiles.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @report_profile, policy_class: Adm::DeficiencyReports::ReportProfilePolicy

    if @report_profile.update(report_profile_params)
      redirect_to adm_deficiency_reports_report_profiles_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.report_profiles.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @report_profile, policy_class: Adm::DeficiencyReports::ReportProfilePolicy

    @report_profile.destroy!
    redirect_to adm_deficiency_reports_report_profiles_path, notice: t(".success")
  end

  def pause
    authorize @report_profile, policy_class: Adm::DeficiencyReports::ReportProfilePolicy

    @report_profile.update_column(:paused, true)
    redirect_to adm_deficiency_reports_report_profiles_path, notice: t(".success", name: @report_profile.name)
  end

  def resume
    authorize @report_profile, policy_class: Adm::DeficiencyReports::ReportProfilePolicy

    @report_profile.update_column(:paused, false)
    redirect_to adm_deficiency_reports_report_profiles_path, notice: t(".success", name: @report_profile.name)
  end

  def generate
    authorize @report_profile, policy_class: Adm::DeficiencyReports::ReportProfilePolicy

    deliver = params[:deliver] == "1"
    DeficiencyReport::ManagementReport.start_for(@report_profile, trigger: :manual, deliver: deliver)
    redirect_to adm_deficiency_reports_report_profile_path(@report_profile),
                notice: t(deliver ? ".success_with_delivery" : ".success")
  end

  private

    def load_report_profile
      @report_profile = DeficiencyReport::ReportProfile.find(params[:id])
    end

    def load_form_options
      @categories = DeficiencyReport::Category.all
      @officer_groups = DeficiencyReport::OfficerGroup.order(:name)
      @eligible_recipients = DeficiencyReport::ReportProfile.eligible_recipients
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.deficiency_reports.report_profiles.index.title"), url: adm_deficiency_reports_report_profiles_path, icon: "summarize" },
        { name: action_title }
      ]
    end

    def report_profile_params
      params.require(:deficiency_report_report_profile).permit(
        :name, :instructions, :frequency, :weekday, :day_of_month, :hour, :recipient_emails_text,
        building_blocks: [], category_ids: [], officer_group_ids: [], recipient_user_ids: []
      )
    end
end
