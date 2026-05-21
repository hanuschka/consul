class Adm::Projekts::ProjektsController < Adm::Projekts::BaseController
  before_action :find_projekt, only: [:details, :visibility, :projekt_managers, :map, :phases, :images, :documents, :evaluation, :evaluation_visibility, :update_evaluation_visibility, :generate_evaluation, :evaluation_status, :regenerate_phase_evaluation, :phase_evaluation_status, :evaluation_pdf_options, :evaluation_pdf, :update, :destroy, :toggle_activated, :update_default_phase, :notify_reviewers, :toggle_hide_content_background, :convert_to_new_content_block_mode, :update_color, :update_image, :delete_image]
  before_action :set_back_button_url, only: [:details, :visibility, :projekt_managers, :map, :phases, :images, :documents, :evaluation]

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
      redirect_to details_adm_projekts_projekt_path(@projekt), notice: t(".success")
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
      ImagesQuery
        .new(images_query_params)
        .call
        .page(params[:page])
        .per(24)

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]

    render layout: !request.xhr?
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

    render layout: !request.xhr?
  end

  def evaluation
    authorize [:adm, :projekts, @projekt], :show?
    @evaluation = @projekt.projekt_evaluation

    @breadcrumbs = [
      { name: @projekt.page&.title || @projekt.name, url: details_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def evaluation_visibility
    authorize [:adm, :projekts, @projekt], :update?

    @evaluation = @projekt.projekt_evaluation
    @report_visibility = @projekt.projekt_evaluation_visibility ||
      @projekt.build_projekt_evaluation_visibility
    @phase_visibilities = build_phase_visibility_map(@projekt)

    @back_button_url = evaluation_adm_projekts_projekt_path(@projekt)

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
      report_params: report_visibility_params,
      phase_params: phase_visibility_params
    )

    flash[:notice] = t(".success")

    redirect_to evaluation_visibility_adm_projekts_projekt_path(@projekt)
  end

  def generate_evaluation
    authorize [:adm, :projekts, @projekt], :update?
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
    authorize [:adm, :projekts, @projekt], :update?

    evaluation = @projekt.projekt_evaluation || @projekt.create_projekt_evaluation!(status: :pending)
    projekt_phase = @projekt.projekt_phases.find(params[:phase_id])

    row = evaluation.projekt_phase_evaluations.find_or_initialize_by(projekt_phase_id: projekt_phase.id)
    row.update!(status: :processing)

    ProjektEvaluations::GeneratePhaseEvaluationJob.perform_later(row.id)

    render json: {
      status: row.status,
      projekt_phase_evaluation_id: row.id
    }
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
      phase_id: @originating_phase_id
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

    render turbo_stream: turbo_stream.replace(
      turbo_frame_request_id,
      partial: "adm/projekts/projekts/#{frame_partial_path}",
      locals: { projekt: @projekt }
    )
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

  def import_projekt
    authorize [:adm, :projekts, Projekt], :create?

    @breadcrumbs = [
      { name: t(".title") }
    ]

    @dt_import_url = build_dt_import_url
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

  def convert_to_new_content_block_mode
    authorize [:adm, :projekts, @projekt], :update?

    result = Projekts::ConvertToNewContentBlockMode.call(projekt: @projekt)

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
    @projekt_phase.default_phase = params[param_key][:default_phase]
    @projekt_phases = @projekt.projekt_phases
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_image
    authorize [:adm, :projekts, @projekt], :update?

    page = @projekt.page
    image = page.image || ::Image.new(imageable: page)
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

  private

    def find_projekt
      @projekt = Projekt.find(params[:id])
    end

    def images_query_params
      params.permit(
        :search, :extension, :size_min_mb, :size_max_mb,
        :created_from, :created_to, :updated_from, :updated_to,
        :sort
      ).merge(imageable_type: "Projekt", imageable_id: @projekt.id)
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

    def build_phase_visibility_map(projekt)
      defaults = ProjektPhaseEvaluationVisibility::SECTION_COLUMNS
        .each_with_object({}) { |col, memo| memo[col] = false }

      projekt.projekt_phases.each_with_object({}) do |phase, memo|
        memo[phase.id] = phase.projekt_phase_evaluation_visibility ||
          phase.build_projekt_phase_evaluation_visibility(defaults)
      end
    end

    def report_visibility_params
      return {} if params[:projekt_evaluation_visibility].blank?

      params.require(:projekt_evaluation_visibility).permit(
        *ProjektEvaluationVisibility::REPORT_SECTION_COLUMNS
      )
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
        geozone_affiliation_ids: [],
        registered_address_district_affiliation_ids: [],
        individual_group_value_ids: []
      )
    end

    def create_params
      params.require(:projekt).permit(:name)
    end

    def build_dt_import_url
      Dt.file_import_url(user_id: current_user.id)
    end
end
