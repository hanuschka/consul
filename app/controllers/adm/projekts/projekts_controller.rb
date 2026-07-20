class Adm::Projekts::ProjektsController < Adm::Projekts::BaseController
  PROJEKT_IMAGE_MAX_FILE_SIZE_MB = 40

  before_action :find_projekt, only: [:details, :visibility, :projekt_managers, :map, :phases, :images, :documents, :evaluation, :report_summary, :evaluation_phase, :poll_answer_participation, :poll_answer_crossectional, :evaluation_visibility, :update_evaluation_visibility, :toggle_evaluation_section_visibility, :toggle_evaluation_tab_visibility, :generate_evaluation, :evaluation_status, :regenerate_phase_evaluation, :regenerate_phase_regular_stats, :regenerate_phase_ai_stats, :phase_evaluation_status, :evaluation_pdf_options, :evaluation_pdf, :update, :destroy, :toggle_activated, :update_default_phase, :notify_reviewers, :toggle_hide_content_background, :convert_to_new_content_block_mode, :update_color, :update_taxonomy, :update_image, :delete_image, :generate_image, :generate_image_status]
  before_action :set_back_button_url, only: [:details, :visibility, :projekt_managers, :map, :phases, :images, :documents, :evaluation]
  before_action :process_tags, only: [:update]

  def list
    authorize Projekt, :index?, policy_class: Adm::Projekts::ProjektPolicy

    base_scope = ProjektsQuery.call(policy_scope([:adm, :projekts, Projekt]).reorder(updated_at: :desc), params)
    @pagy, @projekts = pagy(base_scope, limit: 10)

    @name_header_options = { sort: true, search: true }
    @start_date_header_options = { sort: true }
    @end_date_header_options = { sort: true }
  end

  def new
    authorize [:adm, :projekts, Projekt], :create?

    @breadcrumbs = [
      { name: t(".title") }
    ]
  end

  def create
    authorize [:adm, :projekts, Projekt], :create?
    @projekt = Projekt.new(create_params.merge(author: current_user))

    if @projekt.save
      redirect_to page_path(@projekt.page.slug), notice: t(".success")
    else
      redirect_to new_adm_projekts_projekt_path, alert: @projekt.errors.full_messages.join(", ")
    end
  end

  def details
    authorize [:adm, :projekts, @projekt], :show?
    @breadcrumbs = [
      { name: @projekt.page&.title || @projekt.name, id: "breadcrumb-projekt-name" },
      { name: t(".title") }
    ]
  end

  def visibility
    authorize [:adm, :projekts, @projekt], :show?
    @individual_groups = IndividualGroup.hard.visible
    @breadcrumbs = [
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def projekt_managers
    authorize [:adm, :projekts, @projekt], :show?

    # Auto-create assignments for all projekt managers
    ProjektManager.find_each do |pm|
      pm.projekt_manager_assignments.find_or_create_by!(projekt: @projekt)
    end
    @projekt_manager_assignments = @projekt.projekt_manager_assignments.includes(projekt_manager: :user)

    @breadcrumbs = [
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def map
    authorize [:adm, :projekts, @projekt], :show?
    @breadcrumbs = [
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def phases
    authorize [:adm, :projekts, @projekt], :show?
    base_scope = policy_scope([:adm, :projekts, @projekt.projekt_phases])
      .includes(:geozone_restrictions, :age_restriction)
    @projekt_phases = ProjektPhasesQuery.call(base_scope, params)

    @name_header_options = { search: true }

    @breadcrumbs = [
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def images
    authorize [:adm, :projekts, @projekt], :show?

    @assets =
      AdminAssetsQuery
        .new(images_query_params)
        .call
        .with_attached_storage_data
        .merge(policy_scope([:adm, AdminImage]))
        .preload({ projekt: :page }, user: :image)
        .page(params[:page])
        .per(24)

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]

    render layout: !turbo_frame_request?
  end

  def documents
    authorize [:adm, :projekts, @projekt], :show?

    @assets =
      DocumentsQuery
        .new(documents_query_params)
        .call
        .page(params[:page])
        .per(24)

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]

    render layout: !turbo_frame_request?
  end

  def evaluation
    authorize [:adm, :projekts, @projekt], :show?
    @evaluation = @projekt.projekt_evaluation

    @breadcrumbs = [
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def report_summary
    authorize [:adm, :projekts, @projekt], :show?

    @evaluation = @projekt.projekt_evaluation

    return redirect_to(evaluation_adm_projekts_projekt_path(@projekt)) if @evaluation.blank? || !@evaluation.completed?

    @breadcrumbs = [
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t("adm.projekts.projekts.evaluation.title"), url: evaluation_adm_projekts_projekt_path(@projekt) },
      { name: t("adm.projekts.projekts.evaluation.report_summary_card.title") }
    ]
  end

  def evaluation_phase
    authorize [:adm, :projekts, @projekt], :show?

    @evaluation = @projekt.projekt_evaluation

    return redirect_to(evaluation_adm_projekts_projekt_path(@projekt)) if @evaluation.blank? || !@evaluation.completed?

    @phase_row = @evaluation.phase_rows.find do |row|
      (row.data || {})["phase_id"].to_i == params[:phase_id].to_i
    end

    return redirect_to(evaluation_adm_projekts_projekt_path(@projekt)) if @phase_row.nil?

    @active_phase_id = params[:phase_id].to_i
    @projekt_phase = @projekt.projekt_phases.find_by(id: @active_phase_id)
    @selection = PdfServices::EvaluationPdfSelection.all(@evaluation)

    @poll_stats_entries =
      if @projekt_phase.is_a?(ProjektPhase::VotingPhase)
        @projekt_phase.polls.order(id: :desc).map do |poll|
          { poll: poll, stats: Poll::Stats.new(poll) }
        end
      else
        []
      end

    @live_phase_stats =
      if @projekt_phase.is_a?(ProjektPhase::VotingPhase)
        ProjektEvaluations::AggregateStatistics
          .new(@projekt)
          .call_for_phase(@projekt_phase)
          &.dig(:stats)
          &.deep_stringify_keys
      end

    if @projekt_phase.is_a?(ProjektPhase::BudgetPhase)
      budget = @projekt_phase.budget

      if budget.present? && budget.finished? && budget.results_enabled?
        @budget = budget
        @heading = budget.heading
        @budget_results_investments = ::Budget::Result.new(budget, budget.heading).investments
      end
    end

    @back_button_url = evaluation_adm_projekts_projekt_path(@projekt)

    @breadcrumbs = [
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t("adm.projekts.projekts.evaluation.title"), url: evaluation_adm_projekts_projekt_path(@projekt) },
      { name: (@phase_row.data || {})["phase_title"] }
    ]
  end

  def poll_answer_participation
    authorize [:adm, :projekts, @projekt], :show?

    answer = poll_answer

    participation =
      if answer.present?
        PollAnswerDetailsQuery.new(answer).participation
      else
        {}
      end

    render partial: "adm/projekts/projekts/evaluation/poll_answer_participation_section",
           locals: { participation: participation, answer_id: params[:answer_id] },
           layout: false
  end

  def poll_answer_crossectional
    authorize [:adm, :projekts, @projekt], :show?

    answer = poll_answer

    crossectional =
      if answer.present?
        PollAnswerDetailsQuery.new(answer).crossectional
      else
        { answer: nil, groups: [] }
      end

    render partial: "adm/projekts/projekts/evaluation/poll_answer_crossectional_section",
           locals: { crossectional: crossectional, answer_id: params[:answer_id] },
           layout: false
  end

  def evaluation_visibility
    authorize [:adm, :projekts, @projekt], :update?

    @evaluation = @projekt.projekt_evaluation
    @projekt_phases = @projekt.projekt_phases.sorted
      .includes(:projekt_phase_evaluation_visibility)
    @phase_visibilities = build_phase_visibility_map(@projekt_phases)

    back_phase_id = params[:phase_id].to_i
    @back_button_url =
      if back_phase_id.positive? && @projekt_phases.any? { |phase| phase.id == back_phase_id }
        evaluation_phase_adm_projekts_projekt_path(@projekt, phase_id: back_phase_id)
      else
        evaluation_adm_projekts_projekt_path(@projekt)
      end

    @breadcrumbs = [
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t("adm.projekts.projekts.evaluation.title"), url: evaluation_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def update_evaluation_visibility
    authorize [:adm, :projekts, @projekt], :update?

    ProjektEvaluations::UpdateVisibilityService.call(
      projekt: @projekt,
      phase_params: phase_visibility_params
    )

    respond_to do |format|
      format.json { head :no_content }
      format.html do
        flash[:notice] = t(".success")

        redirect_to evaluation_visibility_adm_projekts_projekt_path(@projekt)
      end
    end
  end

  def toggle_evaluation_section_visibility
    authorize [:adm, :projekts, @projekt], :update?

    projekt_phase = @projekt.projekt_phases.find(params[:phase_id])

    ProjektEvaluations::ToggleSectionVisibilityService.call(
      projekt_phase: projekt_phase,
      section_key: params[:section_key],
      visible: params[:visible]
    )

    head :no_content
  end

  def toggle_evaluation_tab_visibility
    authorize [:adm, :projekts, @projekt], :update?

    projekt_phase = @projekt.projekt_phases.find(params[:phase_id])

    ProjektEvaluations::ToggleTabVisibilityService.call(
      projekt_phase: projekt_phase,
      tab: params[:tab],
      visible: params[:visible]
    )

    head :no_content
  end

  def generate_evaluation
    authorize [:adm, :projekts, @projekt], :update?

    evaluation = @projekt.projekt_evaluation || @projekt.build_projekt_evaluation
    evaluation.update!(status: :processing)

    ProjektEvaluations::GenerateEvaluationJob.perform_later(@projekt.id)

    flash[:notice] = I18n.t("adm.projekts.projekts.generate_evaluation.started")

    redirect_to evaluation_adm_projekts_projekt_path(@projekt)
  end

  def evaluation_status
    authorize [:adm, :projekts, @projekt], :show?
    evaluation = @projekt.projekt_evaluation

    render json: {
      status: evaluation&.status || "pending",
      generated_at: evaluation&.generated_at&.iso8601
    }
  end

  def regenerate_phase_evaluation
    enqueue_phase_regeneration(ProjektEvaluations::GeneratePhaseEvaluationJob)
  end

  def regenerate_phase_regular_stats
    enqueue_phase_regeneration(ProjektEvaluations::RegeneratePhaseRegularStatsJob)
  end

  def regenerate_phase_ai_stats
    enqueue_phase_regeneration(ProjektEvaluations::RegeneratePhaseAiStatsJob)
  end

  def phase_evaluation_status
    authorize [:adm, :projekts, @projekt], :show?
    evaluation = @projekt.projekt_evaluation
    row = evaluation&.projekt_phase_evaluations&.find_by(projekt_phase_id: params[:phase_id])

    render json: {
      status: row&.status || "pending",
      generated_at: row&.generated_at&.iso8601,
      error: row&.status == "failed"
    }
  end

  def evaluation_pdf_options
    authorize [:adm, :projekts, @projekt], :show?
    @evaluation = @projekt.projekt_evaluation

    if @evaluation.blank? || !@evaluation.completed?
      redirect_to evaluation_adm_projekts_projekt_path(@projekt)
      return
    end

    @originating_phase_id = resolve_originating_phase_id(@evaluation, params[:phase_id])
    @selection_defaults = PdfServices::EvaluationPdfSelection.defaults_for(
      evaluation: @evaluation,
      phase_id: @originating_phase_id,
      section_group: params[:section_group].presence
    )

    @back_button_url =
      if @originating_phase_id.present?
        evaluation_adm_projekts_projekt_path(@projekt, anchor: "phase-#{@originating_phase_id}")
      else
        evaluation_adm_projekts_projekt_path(@projekt)
      end

    @breadcrumbs = [
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def evaluation_pdf
    authorize [:adm, :projekts, @projekt], :show?
    @evaluation = @projekt.projekt_evaluation

    if @evaluation.blank? || !@evaluation.completed?
      redirect_to evaluation_adm_projekts_projekt_path(@projekt)
      return
    end

    selection = PdfServices::EvaluationPdfSelection.from_params(@evaluation, params[:pdf_options])

    html = render_to_string(
      template: "adm/projekts/projekts/evaluation/pdf",
      layout: "pdf_evaluation",
      locals: {
        projekt: @projekt,
        evaluation: @evaluation,
        selection: selection
      }
    )

    pdf = Grover.new(html, display_url: request.base_url).to_pdf

    send_data pdf,
      filename: "evaluation_#{@projekt.id}_#{Time.current.strftime('%Y%m%d')}.pdf",
      type: "application/pdf",
      disposition: "attachment"
  end

  def update
    authorize [:adm, :projekts, @projekt]

    if @projekt.update(projekt_params)
      flash.now[:success] = t("adm.attribute.update.success")
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          turbo_frame_request_id,
          partial: "adm/projekts/projekts/#{frame_partial_path}",
          locals: { projekt: @projekt }
        )
      end
      format.json { render json: { projekt: @projekt.serialize } }
    end
  end

  def destroy
    authorize [:adm, :projekts, @projekt]

    @projekt.children.each { |child| child.update(parent: nil) }
    @projekt.debates.unscope(where: :hidden_at).each { |debate| debate.update(projekt_id: nil) }
    @projekt.proposals.unscope(where: :hidden_at).each { |proposal| proposal.update(projekt_id: nil) }
    @projekt.polls.unscope(where: :hidden_at).each { |poll| poll.update(projekt_id: nil) }
    @projekt.destroy!

    redirect_to adm_projekts_root_path, notice: t("adm.projekts.projekts.destroy.success")
  end

  def notify_reviewers
    authorize [:adm, :projekts, @projekt], :update?

    NotificationServices::NewProjektNotifier.call(@projekt)

    respond_to do |format|
      format.html { redirect_to page_path(@projekt.page.slug), notice: t(".success") }
      format.json { render json: { success: true, message: t(".success") } }
    end
  end

  def toggle_hide_content_background
    authorize [:adm, :projekts, @projekt], :update?

    @projekt.update!(show_content_background: !@projekt.show_content_background)

    render json: { show_content_background: @projekt.show_content_background }
  end

  def update_color
    authorize [:adm, :projekts, @projekt], :update?

    if @projekt.update(color: params[:color].presence)
      render json: { ok: true, color: @projekt.color }
    else
      render json: { ok: false, errors: @projekt.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  def update_taxonomy
    authorize [:adm, :projekts, @projekt], :update?

    if @projekt.update(taxonomy_params)
      render json: { ok: true }
    else
      render json: { ok: false, errors: @projekt.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  def convert_to_new_content_block_mode
    authorize [:adm, :projekts, @projekt], :update?

    result = ::Projekts::ConvertToNewContentBlockMode.call(projekt: @projekt)

    if result.success?
      flash[:notice] = t("custom.projekts.page.convert_to_content_blocks.success")
    else
      flash[:error] = t("custom.projekts.page.convert_to_content_blocks.error")
    end

    redirect_to page_path(@projekt.page.slug)
  end

  def toggle_activated
    authorize [:adm, :projekts, @projekt], :update?

    setting = @projekt.projekt_settings.find_by(key: "projekt_feature.main.activate")
    new_value = ActiveModel::Type::Boolean.new.cast(params[:projekt][:activated]) ? "active" : ""
    setting.update!(value: new_value)
  end

  def update_default_phase
    authorize [:adm, :projekts, @projekt], :update?

    @projekt_phase = @projekt.projekt_phases.find(params[:projekt_phase_id])
    param_key = @projekt_phase.model_name.param_key
    phase_params = params[param_key] || params[:projekt_phase]
    @projekt_phase.default_phase = phase_params[:default_phase]
    @projekt_phases = @projekt.projekt_phases

    respond_to do |format|
      format.turbo_stream
      format.json { head :ok }
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_image
    authorize [:adm, :projekts, @projekt], :update?

    page = @projekt.page
    image = page.image || ::Image.new(imageable: page)
    image.accepted_content_types_override = AdminImage::ALLOWED_CONTENT_TYPES
    image.max_file_size_override = PROJEKT_IMAGE_MAX_FILE_SIZE_MB
    image.attachment = params.require(:file)
    image.user = current_user

    if image.save
      page.association(:image).reset

      render json: { ok: true, message: t(".success") }
    else
      render json: { ok: false, errors: image.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  def delete_image
    authorize [:adm, :projekts, @projekt], :update?

    @projekt.page.image&.destroy
    @projekt.page.association(:image).reset

    render json: { ok: true, message: t(".success") }
  end

  def generate_image
    authorize [:adm, :projekts, @projekt], :update?

    if !Ai::Settings.ai_available?
      render json: { ok: false }, status: :forbidden
      return
    end

    use_projekt_content = ActiveModel::Type::Boolean.new.cast(params[:use_projekt_content]) == true

    @projekt.update_column(:banner_image_generation_status, "processing")
    ::Projekts::GenerateBannerImageJob.perform_later(
      @projekt.id,
      current_user.id,
      params[:prompt].to_s,
      use_projekt_content
    )

    render json: { status: "processing" }
  end

  def generate_image_status
    authorize [:adm, :projekts, @projekt], :show?

    status = @projekt.banner_image_generation_status || "pending"
    payload = { status: status }

    if status == "completed"
      payload[:image_url] = generated_banner_image_url
    end

    render json: payload
  end

  private

    def enqueue_phase_regeneration(job_class)
      authorize [:adm, :projekts, @projekt], :update?

      evaluation = @projekt.projekt_evaluation || @projekt.create_projekt_evaluation!(status: :pending)
      projekt_phase = @projekt.projekt_phases.find(params[:phase_id])

      row = evaluation.projekt_phase_evaluations.find_or_initialize_by(projekt_phase_id: projekt_phase.id)
      row.update!(status: :processing)

      job_class.perform_later(row.id)

      render json: {
        status: row.status,
        projekt_phase_evaluation_id: row.id
      }
    end

    def find_projekt
      @projekt = Projekt.find(params[:id])
    end

    def poll_answer
      Poll::Question::Answer
        .eager_load(question: { poll: :projekt_phase })
        .where(projekt_phases: { projekt_id: @projekt.id })
        .find_by(id: params[:answer_id])
    end

    def generated_banner_image_url
      attachment = @projekt.page&.image&.attachment
      return nil if attachment.blank?

      Rails.application.routes.url_helpers.rails_blob_url(attachment, only_path: true)
    end

    def images_query_params
      params.permit(
        :search, :extension, :size_min_mb, :size_max_mb,
        :created_from, :created_to, :updated_from, :updated_to,
        :sort
      ).merge(type: "picture", projekt_id: @projekt.id)
    end

    def documents_query_params
      params.permit(
        :search, :extension, :size_min_mb, :size_max_mb,
        :created_from, :created_to, :updated_from, :updated_to,
        :sort
      ).merge(documentable_type: "Projekt", documentable_id: @projekt.id)
    end

    def set_back_button_url
      @back_button_url = adm_projekts_root_path
    end

    def resolve_originating_phase_id(evaluation, raw_phase_id)
      return nil if raw_phase_id.blank?

      candidate = raw_phase_id.to_i
      match = evaluation.phases_data.find { |p| p["phase_id"].to_i == candidate }
      match ? candidate : nil
    end

    def build_phase_visibility_map(phases)
      defaults = ProjektPhaseEvaluationVisibility::SECTION_COLUMNS
        .each_with_object({}) { |col, memo| memo[col] = false }

      phases.each_with_object({}) do |phase, memo|
        memo[phase.id] = phase.projekt_phase_evaluation_visibility ||
          phase.build_projekt_phase_evaluation_visibility(defaults)
      end
    end

    def phase_visibility_params
      return {} if params[:projekt_phase_evaluation_visibilities].blank?

      params.require(:projekt_phase_evaluation_visibilities).permit!.to_h
    end

    def projekt_params
      params.require(:projekt).permit(
        :name, :total_duration_start, :total_duration_end,
        :show_start_date_in_frontend, :show_end_date_in_frontend,
        :geozone_affiliated,
        :landing_page_id,
        :tag_list,
        geozone_affiliation_ids: [],
        registered_address_district_affiliation_ids: [],
        individual_group_value_ids: [],
        sdg_goal_ids: []
      )
    end

    def process_tags
      return if params[:projekt].blank?
      return if params[:projekt][:tag_list_predefined].nil?

      params[:projekt][:tag_list] = params[:projekt][:tag_list_predefined]
      params[:projekt].delete(:tag_list_predefined)
    end

    def create_params
      params.require(:projekt).permit(:name)
    end

    # Inline sidebar editors (SDG goals + category tags) on the projekt page.
    # The category selector submits its value in :tag_list_predefined, which
    # maps onto the taggable :tag_list attribute.
    def taxonomy_params
      if params[:projekt].key?(:tag_list_predefined)
        params[:projekt][:tag_list] = params[:projekt].delete(:tag_list_predefined)
      end

      params.require(:projekt).permit(:tag_list, sdg_goal_ids: [])
    end

    def build_dt_import_url
      Dt.file_import_url(user_id: current_user.id)
    end
end
