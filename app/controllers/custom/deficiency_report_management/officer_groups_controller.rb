class DeficiencyReportManagement::OfficerGroupsController < DeficiencyReportManagement::BaseController
  load_and_authorize_resource :officer_group, class: "DeficiencyReport::OfficerGroup"

  def index; end

  def new; end

  def edit; end

  def create
    @officer_group = DeficiencyReport::OfficerGroup.new(officer_group_params)

    if @officer_group.save
      redirect_to deficiency_report_management_officer_groups_path
    else
      render :new
    end
  end

  def update
    if @officer_group.update(officer_group_params)
      redirect_to deficiency_report_management_officer_groups_path
    else
      render :edit
    end
  end

  def destroy
    @officer_group.destroy!
    redirect_to deficiency_report_management_officer_groups_path, notice: t("custom.admin.deficiency_reports.officer_groups.destroy.destroyed_successfully")
  end

  private

    def officer_group_params
      params.require(:deficiency_report_officer_group).permit(
        :name,
        officer_ids: []
      )
    end
end
