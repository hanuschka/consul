class Api::DeficiencyReportsController < Api::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes
  include MapLocationAttributes

  before_action :find_deficiency_report, only: [:show, :update]

  def index
    check_read_access!
    deficiency_reports = paginate(
      DeficiencyReport
        .includes(
          :author,
          :tags,
          :category,
          :status,
          :responsible,
          :map_location
        )
        .admin_accepted
    )

    deficiency_reports = apply_filters(deficiency_reports)
    deficiency_reports = apply_sorting(deficiency_reports)

    serialized_deficiency_reports = DeficiencyReportSerializer.serialize_collection(deficiency_reports)

    render json: {
      data: { deficiency_reports: serialized_deficiency_reports },
      pagination: pagination_meta(deficiency_reports)
    }
  end

  def show
    check_read_access!
    serialized_deficiency_report = DeficiencyReportSerializer.new(@deficiency_report).serialize

    render json: { data: { deficiency_report: serialized_deficiency_report } }
  end

  def create
    check_admin_access!
    deficiency_report = DeficiencyReport.new(deficiency_report_params)
    deficiency_report.author = @current_client.content_author
    deficiency_report.resource_terms = true
    deficiency_report.admin_accepted = true

    if deficiency_report.save
      process_image_with_base64(deficiency_report, params[:deficiency_report][:image_attributes])
      serialized_deficiency_report = DeficiencyReportSerializer.new(deficiency_report).serialize

      render json: { data: { deficiency_report: serialized_deficiency_report } }, status: 201
    else
      render json: { error: { messages: deficiency_report.errors.full_messages } }, status: 422
    end
  rescue ForbiddenError, UnauthorizedError
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def update
    check_admin_access!
    @deficiency_report.assign_attributes(deficiency_report_params)

    if @deficiency_report.save
      process_image_with_base64(@deficiency_report, params[:deficiency_report][:image_attributes]) if params[:deficiency_report]&.key?(:image_attributes)
      serialized_deficiency_report = DeficiencyReportSerializer.new(@deficiency_report).serialize

      render json: { data: { deficiency_report: serialized_deficiency_report } }
    else
      render json: { error: { messages: @deficiency_report.errors.full_messages } }, status: 422
    end
  rescue ForbiddenError, UnauthorizedError
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  private

  def find_deficiency_report
    @deficiency_report = DeficiencyReport
      .includes(
        :author,
        :tags,
        :category,
        :status,
        :responsible,
        :map_location
      )
      .find(params[:id])
  end

  def deficiency_report_params
    params.require(:deficiency_report).permit(
      :title,
      :description,
      :summary,
      :official_answer,
      :deficiency_report_category_id,
      :deficiency_report_status_id,
      :on_behalf_of,
      :video_url,
      :responsible_id,
      :responsible_type,
      :tag_list,
      map_location_attributes: map_location_attributes
    )
  end

  def apply_filters(deficiency_reports)
    # Filter by category
    if params[:category_id].present?
      deficiency_reports = deficiency_reports.where(deficiency_report_category_id: params[:category_id])
    end

    # Filter by status
    if params[:status_id].present?
      deficiency_reports = deficiency_reports.where(deficiency_report_status_id: params[:status_id])
    end

    # Filter by author
    if params[:author_id].present?
      deficiency_reports = deficiency_reports.by_author(params[:author_id])
    end

    # Filter by assigned/not assigned
    if params[:assigned] == "true"
      deficiency_reports = deficiency_reports.assigned
    elsif params[:assigned] == "false"
      deficiency_reports = deficiency_reports.not_assigned
    end

    # Filter by archived status
    if params[:archived] == "true"
      deficiency_reports = deficiency_reports.archived
    elsif params[:archived] == "false"
      deficiency_reports = deficiency_reports.not_archived
    end

    # Filter by closed status
    if params[:closed] == "true"
      deficiency_reports = deficiency_reports.closed
    elsif params[:closed] == "false"
      deficiency_reports = deficiency_reports.not_closed
    end

    # Search
    if params[:search].present?
      deficiency_reports = deficiency_reports.search(params[:search])
    end

    deficiency_reports
  end

  def apply_sorting(deficiency_reports)
    case params[:order]
    when "hot_score"
      deficiency_reports.sort_by_hot_score
    when "newest"
      deficiency_reports.sort_by_newest
    when "most_commented"
      deficiency_reports.sort_by_most_commented
    else
      deficiency_reports.sort_by_newest
    end
  end
end

