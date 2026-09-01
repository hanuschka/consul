class Adm::DeficiencyReports::DistrictsController < Adm::DeficiencyReports::BaseController
  def index
    authorize ::RegisteredAddress::District, :index?,
      policy_class: Adm::DeficiencyReports::DistrictPolicy

    @districts = policy_scope(::RegisteredAddress::District, policy_scope_class: Adm::DeficiencyReports::DistrictPolicy::Scope)

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.districts"), icon: "location_city" }]
  end

  def edit
    @district = ::RegisteredAddress::District.find(params[:id])
    authorize @district, policy_class: Adm::DeficiencyReports::DistrictPolicy

    @breadcrumbs = breadcrumbs_for_action(@district.name)
  end

  def update
    @district = ::RegisteredAddress::District.find(params[:id])
    authorize @district, policy_class: Adm::DeficiencyReports::DistrictPolicy

    @district.update!(default_deficiency_report_responsible: resolve_responsible)
    redirect_to adm_deficiency_reports_districts_path, notice: t(".success")
  end

  private

    def resolve_responsible
      return nil if params[:default_responsible].blank?

      type, id = params[:default_responsible].split(":")
      case type
      when "OfficerGroup" then DeficiencyReport::OfficerGroup.find(id)
      when "Officer" then DeficiencyReport::Officer.find(id)
      end
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.deficiency_reports.districts.index.title"), url: adm_deficiency_reports_districts_path, icon: "location_city" },
        { name: action_title }
      ]
    end
end
