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
  end

  def edit
    @deficiency_report = DeficiencyReport.find(params[:id])
    @areas = DeficiencyReport::Area.all.order(created_at: :asc)
    @map_coordinates_for_areas = @areas.map do |area|
      [area.id, [area.map_location.latitude, area.map_location.longitude]]
    end.to_h
  end

  def update
    @deficiency_report = DeficiencyReport.find(params[:id])

    if @deficiency_report.update(deficiency_report_params)
      notify_new_officer(@deficiency_report)
      notify_author_about_status_change(@deficiency_report)

      redirect_to deficiency_report_management_deficiency_reports_path, notice: t("custom.admin.deficiency_reports.update.success_notice")
    else
      render :edit
    end
  end

  def destroy
    @deficiency_report = DeficiencyReport.find(params[:id])
    @deficiency_report.destroy!

    redirect_to deficiency_report_management_deficiency_reports_path, notice: t("custom.admin.deficiency_reports.destroy.success_notice")
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
                    :deficiency_report_area_id,
                    :deficiency_report_officer_id, :assigned_at,
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

      @deficiency_reports = @deficiency_reports.where(deficiency_report_officer_id: current_user.deficiency_report_officer.id)
    end

    def notify_new_officer(dr)
      return if dr.deficiency_report_officer_id_before_last_save == dr.deficiency_report_officer_id

      DeficiencyReportMailer.notify_officer(dr).deliver_later
    end

    def notify_author_about_status_change(dr)
      return if dr.deficiency_report_status_id_before_last_save == dr.deficiency_report_status_id

      DeficiencyReportMailer.notify_author_about_status_change(dr).deliver_later
    end
end
