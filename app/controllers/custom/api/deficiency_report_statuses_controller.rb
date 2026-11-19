class Api::DeficiencyReportStatusesController < Api::BaseController
  def index
    check_read_access!
    statuses = paginate(DeficiencyReport::Status.includes(:translations))

    render json: {
      data: {
        deficiency_report_statuses:
          DeficiencyReportStatusSerializer.serialize_collection(statuses, client: current_client)
      },
      pagination: pagination_meta(statuses)
    }
  end
end
