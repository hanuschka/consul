class DeficiencyReportManagement::DistrictsController < DeficiencyReportManagement::BaseController
  skip_authorization_check if: -> { current_user.administrator? || current_user.deficiency_report_manager? }

  def index
    @districts = RegisteredAddress::District.all
  end

  def edit
    @district = RegisteredAddress::District.find(params[:id])
  end

  def update
    @district = RegisteredAddress::District.find(params[:id])

    deficiency_report_responsible = if params["default_deficiency_report_officer_id"].present?
                                      DeficiencyReport::Officer.find(params["default_deficiency_report_officer_id"])
                                    elsif params["default_deficiency_report_officer_group_id"].present?
                                      DeficiencyReport::OfficerGroup.find(params["default_deficiency_report_officer_group_id"])
                                    end

    @district.update!(default_deficiency_report_responsible: deficiency_report_responsible)
    redirect_to deficiency_report_management_districts_path
  end
end
