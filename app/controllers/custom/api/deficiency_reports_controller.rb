class Api::DeficiencyReportsController < Api::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes
  include MapLocationAttributes

  ASSIGNABLE_RESPONSIBLE_TYPES = {
    "DeficiencyReport::Officer" => DeficiencyReport::Officer,
    "DeficiencyReport::OfficerGroup" => DeficiencyReport::OfficerGroup
  }.freeze

  TRANSLATED_ATTRIBUTES = DeficiencyReportSerializer::ADMIN_TRANSLATED_ATTRIBUTES

  ADMIN_ONLY_FILTERS = %w[author_id assigned].freeze

  PRELOADS = [
    :tags,
    :responsible,
    :map_location,
    :translations,
    { category: :translations },
    { subcategory: :translations },
    { status: :translations },
    { intake_channel: :translations },
    { image: { attachment_attachment: :blob } },
    { documents: { attachment_attachment: :blob } },
    { official_answer_documents_attachments: :blob },
    { author: :organization }
  ].freeze

  before_action :find_deficiency_report, only: [:show, :update]

  def index
    check_read_access!
    check_admin_only_filters!
    deficiency_reports = DeficiencyReport
      .includes(PRELOADS)
      .admin_accepted
    deficiency_reports = paginate(apply_sorting(apply_filters(deficiency_reports)))

    serialized_deficiency_reports = DeficiencyReportSerializer.serialize_collection(deficiency_reports, client: current_client)

    render json: {
      data: { deficiency_reports: serialized_deficiency_reports },
      pagination: pagination_meta(deficiency_reports)
    }
  end

  def show
    check_read_access!

    if !admin_client? && !@deficiency_report.publicly_visible?
      return render_not_found
    end

    serialized_deficiency_report = DeficiencyReportSerializer.new(@deficiency_report, client: current_client).serialize

    render json: { data: { deficiency_report: serialized_deficiency_report } }
  end

  def create
    check_admin_access!
    deficiency_report = DeficiencyReport.new(deficiency_report_params)
    deficiency_report.author = @current_client.content_author
    deficiency_report.resource_terms = true
    deficiency_report.admin_accepted = true
    translations = assign_requested_translations(deficiency_report, :deficiency_report, TRANSLATED_ATTRIBUTES)
    assign_document_authors(deficiency_report)
    assign_official_answer_documents(deficiency_report)

    if !assignable_responsible?(deficiency_report)
      render_unassignable_responsible
    elsif !assignable_intake_channel?(deficiency_report)
      render_unassignable_intake_channel
    elsif save_with_translations(deficiency_report, translations)
      process_image_with_base64(deficiency_report, params[:deficiency_report][:image_attributes])
      serialized_deficiency_report = DeficiencyReportSerializer.new(deficiency_report, client: current_client).serialize

      render json: { data: { deficiency_report: serialized_deficiency_report } }, status: 201
    else
      render json: { error: { messages: deficiency_report.errors.full_messages } }, status: 422
    end
  rescue *SELF_RENDERED_ERRORS
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  def update
    check_admin_access!
    @deficiency_report.assign_attributes(with_existing_map_location_id(@deficiency_report, deficiency_report_params))
    translations = assign_requested_translations(@deficiency_report, :deficiency_report, TRANSLATED_ATTRIBUTES)
    assign_document_authors(@deficiency_report)
    assign_official_answer_documents(@deficiency_report)

    if !assignable_responsible?(@deficiency_report)
      render_unassignable_responsible
    elsif !assignable_intake_channel?(@deficiency_report)
      render_unassignable_intake_channel
    elsif save_with_translations(@deficiency_report, translations)
      process_image_with_base64(@deficiency_report, params[:deficiency_report][:image_attributes]) if params[:deficiency_report]&.key?(:image_attributes)
      serialized_deficiency_report = DeficiencyReportSerializer.new(@deficiency_report, client: current_client).serialize

      render json: { data: { deficiency_report: serialized_deficiency_report } }
    else
      render json: { error: { messages: @deficiency_report.errors.full_messages } }, status: 422
    end
  rescue *SELF_RENDERED_ERRORS
    raise
  rescue StandardError => e
    render json: { error: { messages: [e.message] } }, status: 422
  end

  private

  def find_deficiency_report
    @deficiency_report = DeficiencyReport.includes(PRELOADS).find(params[:id])
  end

  # Only staff can be made responsible: any other record type would let a
  # client read back the name of whatever it points the report at.
  def assignable_responsible?(deficiency_report)
    responsible_type = deficiency_report.responsible_type
    responsible_id = deficiency_report.responsible_id
    responsible_class = ASSIGNABLE_RESPONSIBLE_TYPES[responsible_type]

    if !deficiency_report.will_save_change_to_responsible_type? &&
        !deficiency_report.will_save_change_to_responsible_id?
      true
    elsif responsible_type.blank? && responsible_id.blank?
      true
    else
      responsible_class.present? && responsible_class.exists?(id: responsible_id)
    end
  end

  def render_unassignable_responsible
    message = "Responsible must be an existing " \
      "#{ASSIGNABLE_RESPONSIBLE_TYPES.keys.join(" or ")}."

    render json: { error: { messages: [message] } }, status: 422
  end

  def assignable_intake_channel?(deficiency_report)
    intake_channel_id = deficiency_report.deficiency_report_intake_channel_id

    if !deficiency_report.will_save_change_to_deficiency_report_intake_channel_id? ||
        intake_channel_id.blank?
      true
    else
      DeficiencyReport::IntakeChannel.exists?(id: intake_channel_id)
    end
  end

  def render_unassignable_intake_channel
    message = "deficiency_report_intake_channel_id must reference an existing intake channel."

    render json: { error: { messages: [message] } }, status: 422
  end

  def deficiency_report_params
    with_decoded_documents(
      params.require(:deficiency_report).permit(
        :title,
        :description,
        :summary,
        :official_answer,
        :reporter_answer,
        :deficiency_report_category_id,
        :deficiency_report_subcategory_id,
        :deficiency_report_status_id,
        :deficiency_report_intake_channel_id,
        :on_behalf_of,
        :video_url,
        :responsible_id,
        :responsible_type,
        :tag_list,
        map_location_attributes: map_location_attributes_api,
        documents_attributes: document_attributes_api
      )
    )
  end

  # Official answer documents are files attached straight to the report, not
  # document records: new ones are appended, listed ids are removed, and the
  # model checks type, size and count on save.
  def assign_official_answer_documents(deficiency_report)
    new_documents = Array.wrap(params.dig(:deficiency_report, :official_answer_documents))
    removed_ids = Array.wrap(params.dig(:deficiency_report, :remove_official_answer_document_ids)).map { it.to_s.to_i }
    return if new_documents.empty? && removed_ids.empty?

    kept_blobs = deficiency_report.official_answer_documents
      .reject { |attachment| removed_ids.include?(attachment.id) }
      .map(&:blob)
    attachables = new_documents.map { |document| official_answer_attachable(document) }

    deficiency_report.official_answer_documents = kept_blobs + attachables
  end

  def official_answer_attachable(document)
    if !document.is_a?(ActionController::Parameters)
      raise ActionController::ParameterMissing, :official_answer_documents
    end

    decoded_attachment(document[:attachment], document[:title])
  end

  # A read-only client would otherwise get an unfiltered list that looks
  # filtered.
  def check_admin_only_filters!
    if !admin_client? && params.keys.intersect?(ADMIN_ONLY_FILTERS)
      raise ForbiddenError, "The author_id and assigned filters require admin access."
    end
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

    if params[:subcategory_id].present?
      deficiency_reports = deficiency_reports.where(deficiency_report_subcategory_id: params[:subcategory_id])
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
    sorted_deficiency_reports =
      case params[:order]
      when "hot_score"
        deficiency_reports.sort_by_hot_score
      when "most_commented"
        deficiency_reports.sort_by_most_commented
      else
        deficiency_reports.sort_by_newest
      end

    sorted_deficiency_reports.order(id: :desc)
  end
end

