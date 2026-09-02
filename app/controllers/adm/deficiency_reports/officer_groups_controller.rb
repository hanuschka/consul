class Adm::DeficiencyReports::OfficerGroupsController < Adm::DeficiencyReports::BaseController
  def index
    authorize DeficiencyReport::OfficerGroup, :index?,
      policy_class: Adm::DeficiencyReports::OfficerGroupPolicy

    @officer_groups = policy_scope(DeficiencyReport::OfficerGroup, policy_scope_class: Adm::DeficiencyReports::OfficerGroupPolicy::Scope)
                        .order(:name)

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.officer_groups"), icon: "groups" }]
  end

  def new
    @officer_group = DeficiencyReport::OfficerGroup.new
    authorize @officer_group, policy_class: Adm::DeficiencyReports::OfficerGroupPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def edit
    @officer_group = DeficiencyReport::OfficerGroup.find(params[:id])
    authorize @officer_group, policy_class: Adm::DeficiencyReports::OfficerGroupPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @officer_group = DeficiencyReport::OfficerGroup.new(officer_group_params)
    authorize @officer_group, policy_class: Adm::DeficiencyReports::OfficerGroupPolicy

    if @officer_group.save
      redirect_to adm_deficiency_reports_officer_groups_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.officer_groups.new.title"))
      render :new
    end
  end

  def update
    @officer_group = DeficiencyReport::OfficerGroup.find(params[:id])
    authorize @officer_group, policy_class: Adm::DeficiencyReports::OfficerGroupPolicy

    if @officer_group.update(officer_group_params)
      redirect_to adm_deficiency_reports_officer_groups_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.deficiency_reports.officer_groups.edit.title"))
      render :edit
    end
  end

  def destroy
    @officer_group = DeficiencyReport::OfficerGroup.find(params[:id])
    authorize @officer_group, policy_class: Adm::DeficiencyReports::OfficerGroupPolicy

    @officer_group.destroy!
    redirect_to adm_deficiency_reports_officer_groups_path, notice: t(".success")
  end

  private

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.deficiency_reports.officer_groups.index.title"), url: adm_deficiency_reports_officer_groups_path, icon: "groups" },
        { name: action_title }
      ]
    end

    def officer_group_params
      params.require(:deficiency_report_officer_group).permit(:name, :default_email, officer_ids: [])
    end
end
