class DeficiencyReportManagement::DeficiencyReportsController < DeficiencyReportManagement::BaseController
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include DocumentAttributes
  include CustomSearch

  load_and_authorize_resource

  def index
    filter_assigned_reports_only
    @deficiency_reports = apply_filters(@deficiency_reports)

    if params[:responsible].present?
      klass, id = params[:responsible].split("_")
      @deficiency_reports = @deficiency_reports.where(responsible_type: klass, responsible_id: id)
    end

    @deficiency_reports = @deficiency_reports.order(id: :desc)

    unless params[:format] == "csv"
      @deficiency_reports = @deficiency_reports.page(params[:page].presence || 0).per(params[:limit].presence || 20)
    end

    respond_to do |format|
      format.html
      format.csv do
        send_data CsvServices::DeficiencyReportsExporter.call(@deficiency_reports),
          filename: "deficiency_reports-#{Time.zone.today}.csv"
      end
    end
  end

  def show
    @deficiency_report = DeficiencyReport.find(params[:id])
    @official_answer_templates = DeficiencyReport::OfficialAnswerTemplate.all

    set_current_responsible

    respond_to do |format|
      format.html
      format.pdf do
        pdf_content = PdfServices::DeficiencyReportExporter.call(@deficiency_report, request.host)
        send_data pdf_content.render, filename: "deficiency_report_#{params[:id]}.pdf", type: "application/pdf"
      end
    end
  end

  def edit
    @deficiency_report = DeficiencyReport.find(params[:id])
    @districts = RegisteredAddress::District.joins(:map_location).order(created_at: :asc)
    @map_coordinates_for_districts = @districts.map do |district|
      [district.id, [district.map_location.latitude, district.map_location.longitude]]
    end.to_h
  end

  def update
    @deficiency_report = DeficiencyReport.find(params[:id])

    update_responsible

    if @deficiency_report.update(deficiency_report_params)
      notify_new_officer(@deficiency_report)
      notify_author_about_status_change(@deficiency_report)
      update_status_change_date(@deficiency_report)

      redirect_to deficiency_report_management_deficiency_reports_path, notice: t("custom.admin.deficiency_reports.update.success_notice")
    else
      render :edit
    end
  end

  def destroy
    @deficiency_report = DeficiencyReport.find(params[:id])
    @deficiency_report.destroy!
  end

  def audits
  end

  def accept
    enabled = ["1", "true"].include?(params[:deficiency_report][:admin_accepted])
    deficiency_report = DeficiencyReport.find(params[:deficiency_report][:id])

    deficiency_report.update!(admin_accepted: enabled)

    head :ok
  end

  def toggle_image
    @deficiency_report.image.toggle!(:concealed)
    redirect_to polymorphic_path([@namespace, @deficiency_report], action: :edit)
  end

  private

    def deficiency_report_params
      attributes = [:video_url, :on_behalf_of,
                    :deficiency_report_category_id,
                    :deficiency_report_status_id,
                    map_location_attributes: map_location_attributes,
                    documents_attributes: document_attributes,
                    image_attributes: image_attributes]
      params.require(:deficiency_report).permit(attributes, translation_params(DeficiencyReport))
    end

    def filter_assigned_reports_only
      return if current_user.administrator? || current_user.deficiency_report_manager?
      return unless Setting["deficiency_reports.admins_must_assign_officer"].present?
      raise CanCan::AccessDenied unless current_user.deficiency_report_officer?

      deficiency_report_ids = @deficiency_reports.select do |dr|
        dr.responsible.is_a?(DeficiencyReport::Officer) && dr.responsible == current_user.deficiency_report_officer ||
          dr.responsible.is_a?(DeficiencyReport::OfficerGroup) && dr.responsible.officers.include?(current_user.deficiency_report_officer)
      end

      @deficiency_reports = @deficiency_reports.where(id: deficiency_report_ids)
    end

    def notify_new_officer(dr)
      return if dr.responsible_id_before_last_save == dr.responsible_id && dr.responsible_type_before_last_save == dr.responsible_type

      if dr.responsible.is_a?(DeficiencyReport::Officer)
        DeficiencyReportMailer.notify_officer(dr, dr.responsible).deliver_later
      elsif dr.responsible.is_a?(DeficiencyReport::OfficerGroup)
        dr.responsible.officers.each do |officer|
          DeficiencyReportMailer.notify_officer(dr, officer).deliver_later
        end
      end
    end

    def notify_author_about_status_change(dr)
      return if dr.deficiency_report_status_id_before_last_save == dr.deficiency_report_status_id

      DeficiencyReportMailer.notify_author_about_status_change(dr).deliver_later
    end

    def update_status_change_date(dr)
      return if dr.deficiency_report_status_id_before_last_save == dr.deficiency_report_status_id

      dr.update_column(:status_changed_at, Time.zone.now)
    end

    def set_current_responsible
      if @deficiency_report.responsible.is_a?(DeficiencyReport::Officer)
        @deficiency_report.officer_id = @deficiency_report.responsible.id
      elsif @deficiency_report.responsible.is_a?(DeficiencyReport::OfficerGroup)
        @deficiency_report.officer_group_id = @deficiency_report.responsible.id
      end
    end

    def update_responsible
      current_responsible = @deficiency_report.responsible

      if params[:deficiency_report]["officer_id"].present?
        @deficiency_report.responsible = DeficiencyReport::Officer.find(params[:deficiency_report]["officer_id"])
      elsif params[:deficiency_report]["officer_group_id"].present?
        @deficiency_report.responsible = DeficiencyReport::OfficerGroup.find(params[:deficiency_report]["officer_group_id"])
      end

      new_responsible = @deficiency_report.responsible
      @deficiency_report.assigned_at = Time.zone.now unless current_responsible == new_responsible
    end
end
