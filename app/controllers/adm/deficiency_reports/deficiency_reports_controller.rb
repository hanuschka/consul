class Adm::DeficiencyReports::DeficiencyReportsController < Adm::DeficiencyReports::BaseController
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include DocumentAttributes

  def index
    base_scope = policy_scope(DeficiencyReport, policy_scope_class: Adm::DeficiencyReports::DeficiencyReportPolicy::Scope)
    base_scope = filter_assigned_reports_only(base_scope)
    @pagy, @deficiency_reports = pagy(Adm::DeficiencyReportsQuery.call(base_scope, params))

    @title_header_options = { search: true }
    @created_at_header_options = { sort: true }
    @category_header_options = { filter_options: category_filter_options }
    @status_header_options = { filter_options: status_filter_options }
    @responsible_header_options = { filter_options: responsible_filter_options }

    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.deficiency_reports") }]
  end

  def settings
    authorize :deficiency_report, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy
    @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.settings") }]
  end

  def show
    @deficiency_report = DeficiencyReport.with_hidden.find(params[:id])
    authorize @deficiency_report, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @official_answer_templates = DeficiencyReport::OfficialAnswerTemplate.all

    respond_to do |format|
      format.html do
        @breadcrumbs = [
          { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path },
          { name: @deficiency_report.title }
        ]

        @image_url = @deficiency_report.image&.attachment&.variant(
          resize_to_limit: [500, 500],
          format: "jpeg"
        )
      end
      format.pdf do
        pdf_content = PdfServices::DeficiencyReportExporter.call(@deficiency_report, request.host)
        send_data pdf_content.render, filename: "deficiency_report_#{params[:id]}.pdf", type: "application/pdf"
      end
      format.csv do
        send_data CsvServices::DeficiencyReportsExporter.call(DeficiencyReport.where(id: @deficiency_report.id)),
          filename: "deficiency_reports-#{Time.zone.today}.csv"
      end
    end
  end

  def edit
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    unless turbo_frame_request?
      redirect_to adm_deficiency_reports_deficiency_report_path(@deficiency_report)
      return
    end

    @deficiency_report.build_image(user: current_user) unless @deficiency_report.image
    @deficiency_report.create_map_location unless @deficiency_report.map_location

    @breadcrumbs = [
      { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path },
      { name: @deficiency_report.title }
    ]
  end

  def update
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    update_responsible

    if @deficiency_report.update(deficiency_report_params)
      notify_new_officer(@deficiency_report)
      notify_author_about_status_change(@deficiency_report)
      update_status_change_date(@deficiency_report)
      redirect_to adm_deficiency_reports_deficiency_report_path(@deficiency_report), notice: t("adm.attribute.update.success")
    else
      @deficiency_report.build_image(user: current_user) unless @deficiency_report.image
      @deficiency_report.create_map_location unless @deficiency_report.map_location
      @breadcrumbs = [
        { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path },
        { name: @deficiency_report.title }
      ]
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @deficiency_report.destroy!
  end

  def administer
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, :update?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @breadcrumbs = [
      { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path },
      { name: @deficiency_report.title }
    ]
  end

  def audits
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, :show?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy
  end

  def accept
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, :update?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    accepted = ActiveModel::Type::Boolean.new.cast(params[:deficiency_report][:admin_accepted])
    @deficiency_report.update!(admin_accepted: accepted)
  end

  def toggle_image
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, :update?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @deficiency_report.image.toggle!(:concealed)
    redirect_to adm_deficiency_reports_deficiency_report_path(@deficiency_report)
  end

  def feedback_form
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @feedback_form = @deficiency_report.feedback_form

    @breadcrumbs = [
      { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path },
      { name: @deficiency_report.title }
    ]
  end

  def update_official_answer
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, :update?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    if @deficiency_report.update(params.require(:deficiency_report).permit(:official_answer))
      flash.now[:success] = t(".success")
    end

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@deficiency_report, :official_answer),
      Adm::AttributeEditorComponent.new(
        @deficiency_report,
        :official_answer,
        :rich_text,
        path: update_official_answer_adm_deficiency_reports_deficiency_report_path(@deficiency_report),
        label: t("adm.deficiency_reports.deficiency_reports.show.official_answer"),
        description: t("adm.deficiency_reports.deficiency_reports.show.official_answer_hint")
      )
    )
  end

  private

    def deficiency_report_params
      attributes = [:title, :description, :video_url, :on_behalf_of,
                    :deficiency_report_category_id,
                    :deficiency_report_status_id,
                    map_location_attributes: map_location_attributes,
                    documents_attributes: document_attributes,
                    image_attributes: image_attributes]
      params.require(:deficiency_report).permit(attributes)
    end

    def filter_assigned_reports_only(scope)
      return scope if current_user.administrator? || current_user.deficiency_report_manager?
      return scope unless Setting["deficiency_reports.admins_must_assign_officer"].present?
      raise Pundit::NotAuthorizedError unless current_user.deficiency_report_officer?

      officer = current_user.deficiency_report_officer
      officer_group_ids = DeficiencyReport::OfficerGroup.joins(:officers).where(deficiency_report_officers: { id: officer.id }).pluck(:id)

      scope.where(
        "(responsible_type = ? AND responsible_id = ?) OR (responsible_type = ? AND responsible_id IN (?))",
        "DeficiencyReport::Officer", officer.id,
        "DeficiencyReport::OfficerGroup", officer_group_ids
      )
    end

    def category_filter_options
      DeficiencyReport::Category.all.map { |c| [c.id, c.name] }
    end

    def status_filter_options
      DeficiencyReport::Status.all.map { |s| [s.id, s.title] }
    end

    def responsible_filter_options
      officers = DeficiencyReport::Officer.all.map { |o| [o.id, o.name] }
      groups = DeficiencyReport::OfficerGroup.all.map { |g| [g.id, g.name] }
      officers + groups
    end

    def notify_new_officer(dr)
      return if dr.responsible_id_before_last_save == dr.responsible_id && dr.responsible_type_before_last_save == dr.responsible_type

      if dr.responsible.is_a?(DeficiencyReport::Officer)
        DeficiencyReportMailer.notify_officer(dr, dr.responsible).deliver_later
      elsif dr.responsible.is_a?(DeficiencyReport::OfficerGroup)
        if dr.responsible.default_email.present?
          DeficiencyReportMailer.notify_default_officer_group_email(dr).deliver_later
        end

        dr.responsible.officers.each do |officer|
          DeficiencyReportMailer.notify_officer(dr, officer).deliver_later
        end
      end
    end

    def notify_author_about_status_change(dr)
      return if dr.deficiency_report_status_id_before_last_save == dr.deficiency_report_status_id

      DeficiencyReportMailer.notify_author_about_status_change(dr).deliver_later

      if Setting["deficiency_reports.send_feedback_form_link"].present? &&
          dr.deficiency_report_status_id.in?(DeficiencyReport::Status.where(archive_reports: true).pluck(:id))
        DeficiencyReportMailer.send_feedback_form_link(dr).deliver_later(wait: 24.hours)
      end
    end

    def update_status_change_date(dr)
      return if dr.deficiency_report_status_id_before_last_save == dr.deficiency_report_status_id

      dr.update_column(:status_changed_at, Time.zone.now)
    end

    def update_responsible
      if params[:deficiency_report]["officer_id"].present?
        new_responsible = DeficiencyReport::Officer.find(params[:deficiency_report]["officer_id"])
      elsif params[:deficiency_report]["officer_group_id"].present?
        new_responsible = DeficiencyReport::OfficerGroup.find(params[:deficiency_report]["officer_group_id"])
      end

      return unless new_responsible

      current_responsible = @deficiency_report.responsible
      @deficiency_report.responsible = new_responsible
      @deficiency_report.assigned_at = Time.zone.now unless current_responsible == new_responsible
    end
end
