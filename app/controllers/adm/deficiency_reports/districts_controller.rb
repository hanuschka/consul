class Adm::DeficiencyReports::DistrictsController < Adm::DeficiencyReports::BaseController
  def index
    @districts = policy_scope(::RegisteredAddress::District, policy_scope_class: Adm::DeficiencyReports::DistrictPolicy::Scope)

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.districts") }]
  end

  def edit
    @district = ::RegisteredAddress::District.find(params[:id])
    authorize @district, policy_class: Adm::DeficiencyReports::DistrictPolicy

    @breadcrumbs = breadcrumbs_for_action(@district.name)
  end

  def update
    @district = ::RegisteredAddress::District.find(params[:id])
    authorize @district, policy_class: Adm::DeficiencyReports::DistrictPolicy

    deficiency_report_responsible = if params["default_deficiency_report_officer_id"].present?
                                      DeficiencyReport::Officer.find(params["default_deficiency_report_officer_id"])
                                    elsif params["default_deficiency_report_officer_group_id"].present?
                                      DeficiencyReport::OfficerGroup.find(params["default_deficiency_report_officer_group_id"])
                                    end

    @district.update!(default_deficiency_report_responsible: deficiency_report_responsible)
    redirect_to adm_deficiency_reports_districts_path, notice: t(".success")
  end

  private

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.deficiency_reports.districts.index.title"), url: adm_deficiency_reports_districts_path },
        { name: action_title }
      ]
    end
end
