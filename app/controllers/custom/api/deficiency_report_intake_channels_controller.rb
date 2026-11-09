class Api::DeficiencyReportIntakeChannelsController < Api::BaseController
  def index
    check_read_access!
    intake_channels = paginate(DeficiencyReport::IntakeChannel.includes(:translations).order(:id))

    render json: {
      data: {
        deficiency_report_intake_channels:
          DeficiencyReportIntakeChannelSerializer.serialize_collection(intake_channels)
      },
      pagination: pagination_meta(intake_channels)
    }
  end
end
