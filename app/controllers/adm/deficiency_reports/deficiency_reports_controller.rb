class Adm::DeficiencyReports::DeficiencyReportsController < Adm::DeficiencyReports::BaseController
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include DocumentAttributes
  include DeficiencyReportAiCategorization

  helper_method :assignment_scope_filter?

  def index
    params[:archived_state] = ["active"] if params[:archived_state].blank?
    params[:hidden_state] = ["visible"] if params[:hidden_state].blank?
    params[:assignment_scope] = ["assigned_to_me"] if assignment_scope_filter? &&
                                                      params[:assignment_scope].blank?

    base_scope = scoped_deficiency_reports

    respond_to do |format|
      format.html do
        preloaded = base_scope.preload(:status, :translations, :author, :recorded_by, :category, :subcategory,
                                       :intake_channel, :responsible, :feedback_form, :watches,
                                       map_location: :district)
        @pagy, @deficiency_reports = pagy(Adm::DeficiencyReportsQuery.call(preloaded, params, current_user: current_user))

        @id_header_options = { search: true, sort: true }
        @title_header_options = { search: true }
        @author_header_options = { search: true }
        @on_behalf_of_header_options = { search: true }
        @intake_channel_header_options = { filter_options: intake_channel_filter_options }
        @created_at_header_options = { sort: true, date_range: true }
        @updated_at_header_options = { sort: true, date_range: true }
        @status_changed_at_header_options = { sort: true, date_range: true }
        @status_header_options = { filter_options: status_filter_options }
        @address_header_options = { search: true }
        @district_header_options = { filter_options: district_filter_options }
        @category_header_options = { filter_options: category_filter_options }
        @subcategory_header_options = { filter_options: subcategory_filter_options }
        @responsible_header_options = { filter_options: responsible_filter_options }
        @assignment_scope_header_options = { filter_options: assignment_scope_filter_options, default: ["assigned_to_me"] }
        @archived_state_header_options = { filter_options: archived_state_filter_options, default: ["active"] }
        @hidden_state_header_options = { filter_options: hidden_state_filter_options, default: ["visible"] }

        @breadcrumbs = [{ name: t("adm.deficiency_reports.menu.items.deficiency_reports"), icon: "report_problem" }]
      end

      format.csv do
        scope = Adm::DeficiencyReportsQuery.call(base_scope.preload(:author, :recorded_by), params,
                                                 current_user: current_user)
        send_data CsvServices::DeficiencyReportsExporter.call(scope),
          filename: "deficiency_reports-#{Time.zone.today}.csv",
          type: "text/csv"
      end

      format.geojson do
        scope = Adm::DeficiencyReportsQuery.call(base_scope, params, current_user: current_user).preload(:category)
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
      recorded_by: current_user,
      status: DeficiencyReport::Status.default,
      status_changed_at: Time.zone.now,
      resource_terms: "1"
    ))
    authorize @deficiency_report, :create?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    ai_result = categorize_with_ai(@deficiency_report)

    if @deficiency_report.valid? && link_on_behalf_of_account(@deficiency_report) && @deficiency_report.save
      @deficiency_report.assign_default_responsible
      redirect_to adm_deficiency_reports_deficiency_report_path(@deficiency_report),
        notice: create_notice(ai_result)
    else
      clear_ai_categorization(@deficiency_report) if ai_result
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

        @image_url = @deficiency_report.image&.attachment_variant(
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

  # The bell. Watching is per person, so this only ever touches the caller's own row.
  def toggle_watch
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    watch = @deficiency_report.watches.find_by(user: current_user)

    if watch
      watch.destroy!
    else
      @deficiency_report.watches.create!(user: current_user)
    end

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@deficiency_report, :watch_toggle),
      partial: "adm/deficiency_reports/deficiency_reports/watch_toggle",
      locals: { deficiency_report: @deficiency_report.reload, labeled: params[:labeled].present? }
    )
  end

  # Sharing an Anliegen with colleagues is the same act as switching their bell on: the watch is what
  # earns them the change notifications, the read access, and the "Unter Beobachtung" filter entry.
  # So there is no separate sharing record — recipients simply become watchers.
  def share
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    already_watching = @deficiency_report.watches.pluck(:user_id)
    recipients = share_recipients.reject do |user|
      user == current_user || user.id.in?(already_watching)
    end

    recipients.each do |user|
      @deficiency_report.watches.create!(user: user)
      DeficiencyReportMailer.notify_shared_report(@deficiency_report, user, current_user).deliver_later
    end

    redirect_to adm_deficiency_reports_deficiency_report_path(@deficiency_report),
      notice: t(".success", count: recipients.size)
  end

  # The opt-out link in the "shared with you" mail. Same effect as the bell, but always off rather
  # than a toggle, so following the link twice cannot switch notifications back on.
  def unwatch
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    @deficiency_report.watches.find_by(user: current_user)&.destroy

    # Opting out of a shared Anliegen can remove the very access the share granted, so only return to
    # it while it is still readable — otherwise the redirect bounces straight off the policy.
    still_readable = Adm::DeficiencyReports::DeficiencyReportPolicy
                       .new(current_user, @deficiency_report.reload).show?

    redirect_to(
      still_readable ? adm_deficiency_reports_deficiency_report_path(@deficiency_report) : adm_deficiency_reports_deficiency_reports_list_path,
      notice: t(".success")
    )
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
    authorize @deficiency_report, :accept?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

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

  def remove_official_answer_document
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, :update?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    attachment = @deficiency_report.official_answer_documents.find_by(id: params[:attachment_id])
    attachment&.purge

    redirect_to adm_deficiency_reports_deficiency_report_path(@deficiency_report),
      notice: t(".success")
  end

  def update_official_answer
    @deficiency_report = DeficiencyReport.find(params[:id])
    authorize @deficiency_report, :update?, policy_class: Adm::DeficiencyReports::DeficiencyReportPolicy

    answer_was = @deficiency_report.official_answer.presence
    documents = Array(params[:deficiency_report][:official_answer_documents]).reject(&:blank?)

    if @deficiency_report.update(params.require(:deficiency_report).permit(:official_answer))
      answer_now = @deficiency_report.official_answer.presence

      notify_watchers_about_change(@deficiency_report) if answer_now != answer_was

      if documents.any? && !@deficiency_report.official_answer_documents.attach(documents)
        flash.now[:attachment_alert] = @deficiency_report.errors.full_messages.first
        @deficiency_report.reload
      else
        flash.now[:success] = t(".success")
      end
    end

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@deficiency_report, :official_answer),
      partial: "adm/deficiency_reports/deficiency_reports/official_answer_form",
      locals: { deficiency_report: @deficiency_report }
    )
  end

  private

    # Share targets arrive as "Officer:12" / "OfficerGroup:3", the same encoding the assignment field
    # uses. A group resolves to its members, because notifications go to people, not to a group row.
    def share_recipients
      users = Array(params[:recipients]).compact_blank.flat_map do |value|
        type, id = value.split(":")

        case type
        when "Officer"      then DeficiencyReport::Officer.where(id: id).filter_map(&:user)
        when "OfficerGroup" then DeficiencyReport::OfficerGroup.find_by(id: id)&.officers&.filter_map(&:user) || []
        else []
        end
      end

      users.uniq
    end

    # Only case workers get the three-way filter, and only while the visibility setting is on.
    # Without the setting their scope is already narrowed to their own Anliegen, and for a manager or
    # administrator — who is not an officer — "Mir zugewiesen" would always be empty.
    def assignment_scope_filter?
      Setting["deficiency_reports.officers_see_all_reports"].present? &&
        current_user.deficiency_report_officer?
    end

    def deficiency_report_params
      attributes = [:title, :description, :video_url, :on_behalf_of,
                    :deficiency_report_category_id,
                    :deficiency_report_subcategory_id,
                    :deficiency_report_status_id,
                    :deficiency_report_intake_channel_id,
                    map_location_attributes: map_location_attributes,
                    documents_attributes: document_attributes,
                    image_attributes: image_attributes]
      params.require(:deficiency_report).permit(attributes)
    end

    def create_notice(ai_result)
      return t("adm.attribute.create.success") unless ai_result&.fallback?

      t(".ai_fallback", category: ai_result.category&.name)
    end

    def clear_ai_categorization(deficiency_report)
      deficiency_report.category = nil
      deficiency_report.subcategory = nil
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

    def intake_channel_filter_options
      DeficiencyReport::IntakeChannel.all.map { |c| [c.id, c.name] }
    end

    def responsible_filter_options
      deficiency_report_all_responsible_sorted.map do |r|
        ["#{r.class.name.demodulize}_#{r.id}", r.name]
      end
    end

    def assignment_scope_filter_options
      %w[assigned_to_me watching all].map do |value|
        [value, t("adm.deficiency_reports.deficiency_reports.index.assignment_scope.#{value}")]
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

        if dr.email_officers_individually?
          dr.responsible.officers.each do |officer|
            DeficiencyReportMailer.notify_officer(dr, officer).deliver_later
          end
        end
      end

      mailed_users = dr.email_officers_individually? ? dr.responsible_officers.filter_map(&:user) : []

      notify_watchers_about_change(dr, except: mailed_users)
    end

    def notify_author_about_status_change(dr)
      return if dr.deficiency_report_status_id_before_last_save == dr.deficiency_report_status_id

      DeficiencyReportMailer.notify_author_about_status_change(dr).deliver_later
      notify_watchers_about_change(dr)

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
