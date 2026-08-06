class Adm::DeficiencyReports::DeficiencyReportsController < Adm::DeficiencyReports::BaseController
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include DocumentAttributes

  def index
    params[:archived_state] = ["active"] if params[:archived_state].blank?
    params[:hidden_state] = ["visible"] if params[:hidden_state].blank?

    base_scope = policy_scope(DeficiencyReport, policy_scope_class: Adm::DeficiencyReports::DeficiencyReportPolicy::Scope)
    base_scope = filter_assigned_reports_only(base_scope)

    respond_to do |format|
      format.html do
        preloaded = base_scope.preload(:status, :translations, :author, :category, :subcategory,
                                       :responsible, :feedback_form, map_location: :district)
        @pagy, @deficiency_reports = pagy(Adm::DeficiencyReportsQuery.call(preloaded, params))

        @id_header_options = { search: true, sort: true }
        @title_header_options = { search: true }
        @author_header_options = { search: true }
        @created_at_header_options = { sort: true, date_range: true }
        @updated_at_header_options = { sort: true, date_range: true }
        @status_changed_at_header_options = { sort: true, date_range: true }
        @status_header_options = { filter_options: status_filter_options }
        @address_header_options = { search: true }
        @district_header_options = { filter_options: district_filter_options }
        @category_header_options = { filter_options: category_filter_options }
        @subcategory_header_options = { filter_options: subcategory_filter_options }
        @responsible_header_options = { filter_options: responsible_filter_options }
        @archived_state_header_options = { filter_options: archived_state_filter_options, default: ["active"] }
        @hidden_state_header_options = { filter_options: hidden_state_filter_options, default: ["visible"] }

        @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.deficiency_reports"), icon: "report_problem" }]
      end

      format.csv do
        scope = Adm::DeficiencyReportsQuery.call(base_scope, params)
        send_data CsvServices::DeficiencyReportsExporter.call(scope),
          filename: "deficiency_reports-#{Time.zone.today}.csv",
          type: "text/csv"
      end

      format.geojson do
        scope = Adm::DeficiencyReportsQuery.call(base_scope, params).preload(:category)
        send_data GeoServices::MappablesGeojsonExporter.call(scope),
          filename: "deficiency_reports-#{Time.zone.today}.geojson",
          type: "application/geo+json"
      end
    end
  end

  def new
    @deficiency_report = DeficiencyReport.new
    authorize @deficiency_report, :new?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @deficiency_report.build_image(user: current_user)
    @deficiency_report.build_map_location

    @breadcrumbs = new_breadcrumbs
  end

  def create
    @deficiency_report = DeficiencyReport.new(create_params.merge(
      author: current_user,
      status: DeficiencyReport::Status.default,
      status_changed_at: Time.zone.now,
      resource_terms: "1"
    ))
    authorize @deficiency_report, :create?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    if @deficiency_report.valid? && link_on_behalf_of_account(@deficiency_report) && @deficiency_report.save
      @deficiency_report.assign_default_responsible
      redirect_to adm_deficiency_reports_deficiency_report_path(@deficiency_report), notice: t("adm.attribute.create.success")
    else
      @deficiency_report.build_image(user: current_user) unless @deficiency_report.image
      @deficiency_report.build_map_location unless @deficiency_report.map_location
      @breadcrumbs = new_breadcrumbs
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @deficiency_report = DeficiencyReport.with_hidden.find(params[:id])
    authorize @deficiency_report, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @official_answer_templates = DeficiencyReport::OfficialAnswerTemplate.all

    respond_to do |format|
      format.html do
        @breadcrumbs = [
          { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path, icon: "report_problem" },
          { name: @deficiency_report.title }
        ]

        @image_url = @deficiency_report.image&.attachment&.variant(
          resize_to_limit: [580, nil],
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
      { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path, icon: "report_problem" },
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
        { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path, icon: "report_problem" },
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
    redirect_to adm_deficiency_reports_deficiency_report_path(params[:id])
  end

  def update_administer
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, :update?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    update_responsible

    if @deficiency_report.update(deficiency_report_params)
      notify_new_officer(@deficiency_report)
      notify_author_about_status_change(@deficiency_report)
      update_status_change_date(@deficiency_report)
      flash.now[:success] = t("adm.attribute.update.success")
    end

    @breadcrumbs = [
      { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path, icon: "report_problem" },
      { name: @deficiency_report.title }
    ]
    render :administer
  end

  def audits
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, :show?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @breadcrumbs = [
      { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path, icon: "report_problem" },
      { name: @deficiency_report.title }
    ]
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
      { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path, icon: "report_problem" },
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
                    :deficiency_report_intake_channel_id,
                    map_location_attributes: map_location_attributes,
                    documents_attributes: document_attributes,
                    image_attributes: image_attributes]
      params.require(:deficiency_report).permit(attributes)
    end

    def create_params
      permitted = if params.dig(:deficiency_report, :image_attributes, :cached_attachment).blank?
                    deficiency_report_params.except(:image_attributes)
                  else
                    deficiency_report_params
                  end

      permitted.merge(params.require(:deficiency_report)
        .permit(:on_behalf_of_company_name, :on_behalf_of_email))
    end

    def new_breadcrumbs
      [
        { name: t("adm.deficiency_reports.menu.items.deficiency_reports"), url: adm_deficiency_reports_root_path, icon: "report_problem" },
        { name: t("adm.deficiency_reports.deficiency_reports.new.title") }
      ]
    end

    def filter_assigned_reports_only(scope)
      return scope if current_user.administrator? || current_user.deficiency_report_manager?
      return scope unless Setting["deficiency_reports.admins_must_assign_officer"].present?
      raise Pundit::NotAuthorizedError unless current_user.deficiency_report_officer?

      officer = current_user.deficiency_report_officer

      return scope if officer.manage_all?

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

    # Prefixed with the parent so two categories can both have a "Sonstiges" subcategory without the
    # filter list turning into a guessing game.
    def subcategory_filter_options
      DeficiencyReport::Subcategory.includes(:category).map do |s|
        [s.id, "#{s.category.name} – #{s.name}"]
      end
    end

    def district_filter_options
      scope = policy_scope(::RegisteredAddress::District, policy_scope_class: Adm::DeficiencyReports::DistrictPolicy::Scope)
      scope.pluck(:id, :name)
    end

    def status_filter_options
      DeficiencyReport::Status.all.map { |s| [s.id, s.title] }
    end

    def responsible_filter_options
      deficiency_report_all_responsible_sorted.map do |r|
        ["#{r.class.name.demodulize}_#{r.id}", r.name]
      end
    end

    def archived_state_filter_options
      %w[active archived].map do |state|
        [state, t("adm.deficiency_reports.deficiency_reports.index.archived_state.#{state}")]
      end
    end

    def hidden_state_filter_options
      %w[visible hidden].map do |state|
        [state, t("adm.deficiency_reports.deficiency_reports.index.hidden_state.#{state}")]
      end
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
      responsible_param = params.dig(:deficiency_report, :responsible)
      return if responsible_param.nil?

      new_responsible = resolve_responsible(responsible_param)
      current_responsible = @deficiency_report.responsible
      @deficiency_report.responsible = new_responsible
      @deficiency_report.assigned_at = Time.zone.now unless current_responsible == new_responsible
    end

    def resolve_responsible(value = params[:default_responsible])
      return nil if value.blank?

      type, id = value.split(":")
      case type
      when "OfficerGroup" then DeficiencyReport::OfficerGroup.find(id)
      when "Officer" then DeficiencyReport::Officer.find(id)
      end
    end

end
