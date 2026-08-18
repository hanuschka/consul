class Adm::Projekts::PhasesController < Adm::Projekts::BaseController
  include Adm::Projekts::MitmachboxPhaseActions

  before_action :find_projekt, only: [:new, :create, :reorder]
  before_action :find_projekt_phase, except: [:new, :create, :reorder]
  before_action :set_back_button_url, except: [:new, :create, :reorder, :update, :toggle_active, :toggle_frontend_visibility, :update_age_ranges_for_stats, :send_notifications]

  def new
    authorize @projekt, :create?, policy_class: Adm::Projekts::ProjektPhasePolicy
    @phase_types = ProjektPhase::PROJEKT_PHASES_TYPES
    @phase_types -= ["ProjektPhase::MitmachboxPhase"] unless Mitmachbox.configured?

    @breadcrumbs = [
      { name: @projekt.page.title },
      { name: t("adm.projekts.phases.index.title"), url: phases_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def create
    authorize @projekt, :create?, policy_class: Adm::Projekts::ProjektPhasePolicy

    @projekt_phase = ProjektPhase.new(create_params.merge(active: true))

    if @projekt_phase.save
      create_mitmachbox_remote_survey if @projekt_phase.is_a?(ProjektPhase::MitmachboxPhase)
      redirect_to phases_adm_projekts_projekt_path(@projekt), notice: t(".success")
    else
      redirect_to new_adm_projekts_projekt_phase_path(@projekt), alert: @projekt_phase.errors.full_messages.join(", ")
    end
  end

  def reorder
    authorize @projekt, :update?, policy_class: Adm::Projekts::ProjektPhasePolicy
    ordered_ids = params[:tree].map { |item| item[:id] }
    ProjektPhase.order_phases(ordered_ids)
    head :ok
  end

  def update
    authorize_phase
    if @projekt_phase.update(projekt_phase_params)
      flash.now[:success] = t("adm.attribute.update.success")
    end

    render turbo_stream: turbo_stream.replace(
      turbo_frame_request_id,
      partial: "adm/projekts/phases/#{frame_partial_path}",
      locals: { projekt_phase: @projekt_phase }
    )
  end

  def duration
    authorize_phase(:update?)
    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def naming
    authorize_phase(:update?)

    if @projekt_phase.name == "voting_phase"
      poll = @projekt_phase.poll
      @poll_image = poll.image || poll.build_image(user: current_user)
      @poll_image.save!(validate: false) if @poll_image.new_record?
    end

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def restrictions
    authorize_phase(:update?)
    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def toggle_active
    authorize_phase(:update?)
    @projekt_phase.update(active: !@projekt_phase.active)

    respond_to do |format|
      format.turbo_stream
      format.json { head :ok }
    end
  end

  def toggle_frontend_visibility
    authorize_phase(:update?)
    @projekt_phase.update(frontend_visibility: !@projekt_phase.frontend_visibility)
  end

  def destroy
    authorize_phase(:destroy?)
    @projekt_phase.hide

    respond_to do |format|
      format.html do
        redirect_to phases_adm_projekts_projekt_path(@projekt_phase.projekt),
          notice: t(".success")
      end
      format.json { head :ok }
    end
  end

  def send_notifications
    authorize_phase(:update?)

    case params[:resource_type]
    when "projekt_arguments"
      NotificationServices::ProjektArgumentsNotifier.call(@projekt_phase.id)
    when "projekt_questions"
      NotificationServices::ProjektQuestionsNotifier.call(@projekt_phase.id)
    end

    head :ok
  end

  def general_settings
    authorize_phase(:update?)
    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def form_author
    authorize_phase(:update?)
    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def user_functions
    authorize_phase(:update?)
    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def proposals
    authorize_phase(:moderate?)
    base_scope = ProposalsQuery.call(@projekt_phase.proposals.with_hidden, params)

    respond_to do |format|
      format.html do
        @pagy, @proposals = pagy(base_scope.preload(:author, image: { attachment_attachment: :blob }))

        @title_header_options = { search: true }
        @moderation_header_options = { filter_options: moderation_filter_options }

        @breadcrumbs = [
          { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t(".title") }
        ]
      end
      format.csv do
        send_data CsvServices::ProposalsExporter.call(base_scope),
                  filename: "proposals-#{@projekt_phase.id}-#{Time.zone.today}.csv"
      end
      format.geojson do
        send_data GeoServices::MappablesGeojsonExporter.call(base_scope.preload(:sentiment, :projekt_labels)),
                  filename: "proposals-#{@projekt_phase.id}-#{Time.zone.today}.geojson",
                  type: "application/geo+json"
      end
    end
  end

  def comments
    authorize_phase(:moderate?)
    base_scope = CommentsQuery.call(comments_for_phase, params)

    respond_to do |format|
      format.html do
        @pagy, @comments = pagy(base_scope)

        @moderation_header_options = { filter_options: moderation_filter_options }

        @breadcrumbs = [
          { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t(".title") }
        ]
      end
      format.csv do
        send_data CsvServices::CommentsExporter.call(base_scope),
                  filename: "comments-#{@projekt_phase.id}-#{Time.zone.today}.csv"
      end
    end
  end

  def whatsapp
    authorize_phase(:update?)
    @phase_token = ::Whatsapp::QrToken.for_projekt_phase(@projekt_phase)

    @ai_flow_enabled = @projekt_phase.ai_flow_enabled?

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def ai_user_flow
    authorize_phase(:update?)
    @hard_criteria = @projekt_phase.user_resource_criteria.hard_kind
    @soft_criteria = @projekt_phase.user_resource_criteria.soft_kind

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def create_user_resource_criterion
    authorize_phase(:update?)
    kind = sanitized_kind_param
    return render json: { errors: ["invalid kind"] }, status: :unprocessable_entity if kind.nil?

    criterion = @projekt_phase.user_resource_criteria.build(criterion_create_params.merge(kind: kind))

    if criterion.save
      render json: serialize_criterion(criterion), status: :created
    else
      render json: { errors: criterion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update_user_resource_criterion
    authorize_phase(:update?)
    criterion = @projekt_phase.user_resource_criteria.find(params[:criterion_id])

    if criterion.update(criterion_update_params)
      render json: serialize_criterion(criterion), status: :ok
    else
      render json: { errors: criterion.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy_user_resource_criterion
    authorize_phase(:update?)
    @projekt_phase.user_resource_criteria.find(params[:criterion_id]).destroy

    head :no_content
  end

  def reorder_user_resource_criteria
    authorize_phase(:update?)
    kind = sanitized_kind_param
    return render json: { errors: ["invalid kind"] }, status: :unprocessable_entity if kind.nil?

    scope = @projekt_phase.user_resource_criteria.where(kind: kind)
    params[:order].each_with_index do |id, index|
      scope.where(id: id).update_all(position: index)
    end

    head :ok
  end

  def proposal_criteria
    authorize_phase(:update?)
    @criteria = @projekt_phase.proposal_criteria

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def budget_phases
    authorize_phase(:update?)
    @budget = @projekt_phase.budget
    @budget_phases = @budget&.phases&.order(:id) || Budget::Phase.none

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def budget_edit
    authorize_phase(:update?)
    @budget = @projekt_phase.budget
    @heading = @budget.heading

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def budget_investments
    authorize_phase(:moderate?)
    @budget = @projekt_phase.budget
    base_scope = BudgetInvestmentsQuery.call(@budget.investments.with_hidden.order(id: :desc), params)

    respond_to do |format|
      format.html do
        @pagy, @investments = pagy(base_scope.preload(:author, image: { attachment_attachment: :blob }))

        boolean_filter_options = [[true, t("shared.true")], [false, t("shared.false")]]

        @title_header_options = { search: true }
        @moderation_header_options = { filter_options: moderation_filter_options }
        @feasibility_header_options = {
          filter_options: Budget::Investment::FEASIBILITIES.map do |value|
            [value, Budget::Investment.human_attribute_name("feasibility_#{value}")]
          end
        }
        @valuation_finished_header_options = { filter_options: boolean_filter_options }
        @total_votes_header_options = { sort: true }
        @preselected_header_options = { filter_options: boolean_filter_options }
        @selected_header_options = { filter_options: boolean_filter_options }
        @winner_header_options = { filter_options: boolean_filter_options }
        @district_header_options = {
          filter_options: ::RegisteredAddress::District.order(:name).pluck(:id, :name)
        }

        @breadcrumbs = [
          { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t(".title") }
        ]
      end
      format.csv do
        send_data CsvServices::BudgetInvestmentsExporter.call(base_scope, request.host),
                  filename: "budget_investments-#{@projekt_phase.id}-#{Time.zone.today}.csv"
      end
      format.geojson do
        send_data GeoServices::MappablesGeojsonExporter.call(base_scope.preload(:sentiment, :projekt_labels)),
                  filename: "budget_investments-#{@projekt_phase.id}-#{Time.zone.today}.geojson",
                  type: "application/geo+json"
      end
    end
  end

  def poll_questions
    authorize_phase(:update?)
    @poll = @projekt_phase.poll
    @questions = @poll.questions.root_questions.where(context_id: nil)

    respond_to do |format|
      format.html do
        @breadcrumbs = [
          { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t(".title") }
        ]
      end
      format.csv do
        send_data CsvServices::PollIndividualAnswersExporter.call(@poll),
          filename: "poll_#{@poll.id}_individual_answers-#{Time.zone.today}.csv"
      end
    end
  end

  def go_live
    authorize_phase(:update?)
    @projekt_phase.poll.go_live!

    redirect_to poll_questions_adm_projekts_phase_path(@projekt_phase),
      notice: t(".success")
  end

  def formular
    authorize_phase(:update?)
    @formular = @projekt_phase.formular
    @formular_fields_primary = @formular.formular_fields.primary
    @formular_fields_follow_up = @formular.formular_fields.follow_up

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def formular_answers
    authorize_phase(:update?)
    @formular = @projekt_phase.formular
    @formular_fields = @formular.formular_fields

    respond_to do |format|
      format.html do
        @pagy, @formular_answers = pagy(
          @formular.formular_answers
            .order(:id)
            .preload(
              formular_answer_images: { attachment_attachment: :blob },
              formular_answer_documents: { attachment_attachment: :blob }
            )
        )
        @breadcrumbs = [
          { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t(".title") }
        ]
      end
      format.csv do
        send_data CsvServices::FormularAnswersExporter.call(@formular, request.base_url),
          filename: "formular_answers-#{@formular.id}-#{Time.zone.today}.csv"
      end
    end
  end

  def formular_follow_up_emails
    authorize_phase(:update?)
    @formular = @projekt_phase.formular
    @formular_fields = @formular.formular_fields
    @formular_answers = @formular.formular_answers
    @formular_follow_up_letters = @formular.formular_follow_up_letters

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def milestones
    authorize_phase(:update?)
    @milestones = @projekt_phase.milestones.order_by_publication_date

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def progress_bars
    authorize_phase(:update?)
    @progress_bars = @projekt_phase.progress_bars

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def legislation_process_draft_versions
    authorize_phase(:update?)
    @process = @projekt_phase.legislation_process

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def map
    authorize_phase(:update?)
    @projekt_phase.copy_map_settings_from_projekt unless @projekt_phase.map_location.present?

    @masterportal_pins_count = @projekt_phase.masterportal_pins.count

    if params[:masterportal_import] == "success"
      flash.now[:notice] = t(".masterportal_import_success")
    end

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def masterportal_pins
    authorize_phase(:update?)

    @masterportal_pins_view = (params[:view] == "map") ? "map" : "list"
    @masterportal_pins_search_query = params[:q].to_s.strip
    @masterportal_pins_collection_ids =
      @projekt_phase.masterportal_pins.distinct.pluck(:collection_id).compact.sort

    requested_collection_id = params[:collection_id].to_s.strip.presence
    @masterportal_pins_collection_id =
      if @masterportal_pins_collection_ids.include?(requested_collection_id)
        requested_collection_id
      end

    base_scope = @projekt_phase.masterportal_pins
      .text_search(@masterportal_pins_search_query)

    if @masterportal_pins_collection_id.present?
      base_scope = base_scope.where(collection_id: @masterportal_pins_collection_id)
    end

    if @masterportal_pins_view == "map"
      @masterportal_pins_for_map = base_scope.select(:id, :latitude, :longitude).order(:id)
      @masterportal_pins_total_count = base_scope.count
    else
      list_scope = base_scope
        .includes(:proposal, :budget_investment, :projekt_point_of_interest_pin)
        .order(created_at: :desc)
      @pagy_masterportal_pins, @masterportal_pins = pagy(list_scope, limit: 12)
    end

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t("adm.projekts.phases.map.title"), url: map_adm_projekts_phase_path(@projekt_phase) },
      { name: t(".title") }
    ]
  end

  def masterportal_pins_summary
    authorize_phase(:update?)
    @masterportal_pins_count = @projekt_phase.masterportal_pins.count

    render layout: false
  end

  def destroy_all_masterportal_pins
    authorize_phase(:update?)

    @projekt_phase.update!(masterportal_destroy_status: "running", masterportal_destroy_error: nil)
    MasterportalDestroyAllPinsJob.perform_later(projekt_phase_id: @projekt_phase.id)

    render json: masterportal_destroy_status_payload, status: :accepted
  end

  def destroy_all_masterportal_pins_status
    authorize_phase(:update?)

    render json: masterportal_destroy_status_payload
  end

  def destroy_masterportal_pin
    authorize_phase(:update?)
    pin = @projekt_phase.masterportal_pins.find(params[:masterportal_pin_id])
    Masterportal::DestroyPinService.call(masterportal_pin: pin)

    flash[:success] = t(".success")

    redirect_to masterportal_pins_adm_projekts_phase_path(
      @projekt_phase,
      params.permit(:q, :view, :page, :collection_id).to_h.compact_blank
    )
  end

  def update_masterportal_collection
    authorize_phase(:update?)
    collection = @projekt_phase.masterportal_collections.find(params[:masterportal_collection_id])

    if collection.file_source? && !collection.geojson_file.attached?
      return render json: {
        message: t("adm.projekts.phases.update_masterportal_collection.missing_file")
      }, status: :unprocessable_entity
    end

    collection.update!(import_status: "running", import_error: nil)

    MasterportalImportJob.perform_later(**masterportal_resync_job_args(collection))

    render json: masterportal_collection_status_payload(collection), status: :accepted
  end

  def update_masterportal_collection_color
    authorize_phase(:update?)
    collection = @projekt_phase.masterportal_collections.find(params[:masterportal_collection_id])
    color = masterportal_feature_color_param

    if color.nil?
      return render json: {
        message: t("adm.projekts.phases.update_masterportal_collection_color.invalid_color")
      }, status: :unprocessable_entity
    end

    collection.update!(feature_color: color)

    render json: { feature_color: collection.feature_color }
  end

  def destroy_masterportal_collection
    authorize_phase(:update?)
    collection = @projekt_phase.masterportal_collections.find(params[:masterportal_collection_id])
    collection.update!(destroy_status: "running", destroy_error: nil)

    MasterportalDestroyCollectionJob.perform_later(masterportal_collection_id: collection.id)

    render json: masterportal_collection_status_payload(collection), status: :accepted
  end

  def masterportal_collection_status
    authorize_phase(:update?)
    collection =
      @projekt_phase.masterportal_collections.find_by(id: params[:masterportal_collection_id])

    if collection.nil?
      render json: { deleted: true }

      return
    end

    render json: masterportal_collection_status_payload(collection)
  end

  def masterportal_collection_diff
    authorize_phase(:update?)
    collection = @projekt_phase.masterportal_collections.find(params[:masterportal_collection_id])

    result = Masterportal::CollectionDiffService.call(masterportal_collection: collection)

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(collection),
      Adm::MasterportalCollectionCardComponent.new(
        collection: collection, projekt_phase: @projekt_phase, diff: result
      )
    )
  rescue OgcApiFeatures::Error => e
    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(collection),
      Adm::MasterportalCollectionCardComponent.new(
        collection: collection, projekt_phase: @projekt_phase, diff_error: e.message
      )
    )
  end

  def masterportal_collection_card
    authorize_phase(:update?)
    collection =
      @projekt_phase.masterportal_collections.find_by(id: params[:masterportal_collection_id])

    if collection.nil?
      render turbo_stream: turbo_stream.remove(
        helpers.dom_id(MasterportalCollection.new(id: params[:masterportal_collection_id]))
      )

      return
    end

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(collection),
      Adm::MasterportalCollectionCardComponent.new(collection: collection, projekt_phase: @projekt_phase)
    )
  end

  def clean_masterportal_collection_stale_pins
    authorize_phase(:update?)
    collection = @projekt_phase.masterportal_collections.find(params[:masterportal_collection_id])

    Masterportal::CleanStaleService.call(masterportal_collection: collection)

    head :no_content
  rescue OgcApiFeatures::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end

  def projekt_point_of_interest_categories
    authorize_phase(:update?)
    @categories = @projekt_phase.projekt_point_of_interest_categories.manual.ordered
    @masterportal_collections = @projekt_phase.masterportal_collections.ordered
    enqueue_collection_taxonomy_sync

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def destroy_projekt_point_of_interest_pin
    authorize_phase(:update?)
    pin = @projekt_phase.projekt_point_of_interest_pins.user_created.find(params[:pin_id])
    pin.destroy!

    flash[:success] = t(".success")

    redirect_to projekt_point_of_interest_pins_adm_projekts_phase_path(
      @projekt_phase,
      params.permit(:page).to_h.compact_blank
    )
  end

  def projekt_point_of_interest_pins
    authorize_phase(:update?)
    base_scope = @projekt_phase.projekt_point_of_interest_pins.ordered

    respond_to do |format|
      format.html do
        @pagy, @pins = pagy(base_scope)

        @breadcrumbs = [
          { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t(".title") }
        ]
      end
      format.geojson do
        send_data GeoServices::MappablesGeojsonExporter.call(base_scope.preload(:masterportal_pin)),
                  filename: "projekt_point_of_interest_pins-#{@projekt_phase.id}-#{Time.zone.today}.geojson",
                  type: "application/geo+json"
      end
    end
  end

  def map_resources_overview
    authorize_phase(:update?)

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def projekt_labels
    authorize_phase(:update?)
    @projekt_labels = @projekt_phase.projekt_labels.manual
    @masterportal_collections = @projekt_phase.masterportal_collections.ordered
    enqueue_collection_taxonomy_sync

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def sentiments
    authorize_phase(:update?)
    @sentiments = @projekt_phase.sentiments

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def officing_managers
    authorize_phase(:update?)
    @officing_managers = OfficingManager.all

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def officing_manager_audits
    authorize_phase(:update?)
    poll = @projekt_phase.poll
    poll_voters = Poll::Voter.where(poll_id: poll.id)
                             .where.not(officing_manager_id: nil)

    @pagy, @audits = pagy(Audit.where(auditable: poll_voters).order(created_at: :desc))

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def age_ranges_for_stats
    authorize_phase(:update?)
    @age_ranges = AgeRange.for_stats

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def update_age_ranges_for_stats
    authorize_phase(:update?)
    param_key = @projekt_phase.model_name.param_key
    age_range_ids = params.dig(param_key, :age_ranges_for_stat_ids)&.reject(&:blank?) || []
    @projekt_phase.age_ranges_for_stat_ids = age_range_ids

    redirect_to age_ranges_for_stats_adm_projekts_phase_path(@projekt_phase), flash: { success: t("adm.attribute.update.success") }
  end

  def email_templates
    authorize_phase(:update?)

    @email_template_groups = @projekt_phase.customizable_email_template_groups.map do |group|
      {
        key: group[:key],
        entries: group[:templates].map do |tpl|
          record = @projekt_phase.email_templates.find_or_create_by!(
            mailer_class: tpl[:mailer_class],
            mailer_action: tpl[:mailer_action],
            locale: I18n.locale
          )
          { template: record, recipient_type: tpl[:recipient_type] }
        end
      }
    end

    @email_templates = @email_template_groups.flat_map { |g| g[:entries].map { |e| e[:template] } }

    @breadcrumbs = [
      { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def ai_settings
    authorize_phase(:update?)

    @assistant_codename = @projekt_phase.voice_assistant_codename
    @ai_settings = @projekt_phase.settings.where(key: "feature.form.voice_assistant")

    load_ai_assistant_config if InternalApiClient.active_dt?

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def update_ai_settings
    authorize_phase(:update?)

    dt_response =
      DtApi::Client.new
        .ai_assistant_configs
        .update(
          codename: params[:assistant_codename],
          consul_projekt_phase_id: @projekt_phase.id,
          params: {
            questions: params[:questions],
            criteria: params[:criteria],
            parting_words: params[:parting_words]
          }
        )

    if dt_response["status"] == "error"
      flash[:error] = "Error updating config. #{dt_response["error_message"]}"
    end

    redirect_to ai_settings_adm_projekts_phase_path(@projekt_phase)
  end

  def projekt_notifications
    authorize_phase(:update?)
    @projekt_notifications = @projekt_phase.projekt_notifications.order(created_at: :desc)

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def projekt_events
    authorize_phase(:update?)
    @projekt_events = @projekt_phase.projekt_events.order(datetime: :desc)

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def projekt_livestreams
    authorize_phase(:update?)
    @projekt_livestreams = @projekt_phase.projekt_livestreams

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def projekt_questions
    authorize_phase(:update?)
    @pagy, @projekt_questions = pagy(@projekt_phase.questions.order(id: :desc))

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def projekt_arguments
    authorize_phase(:update?)
    @projekt_arguments_pro = @projekt_phase.projekt_arguments.pro
    @projekt_arguments_cons = @projekt_phase.projekt_arguments.cons

    @breadcrumbs = [
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  private

    # DtApi::Client raises CacheMissError when the DT service is unreachable
    # and no cached response exists yet. The page still renders the phase's
    # local voice-assistant setting, so degrade to an alert instead of a 500.
    def load_ai_assistant_config
      @ai_assistant_config_response =
        DtApi::Client.new(use_cache: true)
          .ai_assistant_configs
          .get(
            codename: @assistant_codename,
            consul_projekt_phase_id: @projekt_phase.id
          )

      @ai_assistant_config = @ai_assistant_config_response["client_ai_assistant_config"]
    rescue DtApi::CacheMissError
      @dt_api_unavailable = true
    end

    def moderation_filter_options
      ProposalsQuery::MODERATION_STATUSES.map do |status|
        [status, t("shared.moderation_statuses.#{status}")]
      end
    end

    def comments_for_phase
      if @projekt_phase.is_a?(ProjektPhase::ProposalPhase)
        Comment.with_hidden.where(commentable: @projekt_phase.proposals.with_hidden)
      elsif @projekt_phase.is_a?(ProjektPhase::BudgetPhase)
        Comment.with_hidden.where(commentable: @projekt_phase.budget.investments.with_hidden)
      else
        @projekt_phase.comments.with_hidden
      end
    end

    def authorize_phase(action = nil)
      if action
        authorize @projekt_phase, action, policy_class: Adm::Projekts::ProjektPhasePolicy
      else
        authorize @projekt_phase, policy_class: Adm::Projekts::ProjektPhasePolicy
      end
    end

    def masterportal_destroy_status_payload
      {
        status: @projekt_phase.masterportal_destroy_status,
        error: @projekt_phase.masterportal_destroy_error
      }
    end

    def masterportal_collection_status_payload(collection)
      {
        import_status: collection.import_status,
        import_error: collection.import_error,
        destroy_status: collection.destroy_status,
        destroy_error: collection.destroy_error
      }
    end

    def enqueue_collection_taxonomy_sync
      return if !Masterportal::CollectionTaxonomySyncService.out_of_sync?(projekt_phase: @projekt_phase)

      MasterportalCollectionTaxonomySyncJob.perform_later(projekt_phase_id: @projekt_phase.id)
    end

    def masterportal_feature_color_param
      color = params[:feature_color].to_s.strip
      return nil if color.blank?

      color.match?(/\A#[0-9a-fA-F]{6}\z/) ? color : nil
    end

    def masterportal_resync_job_args(collection)
      args = {
        projekt_phase_id: @projekt_phase.id,
        create_domain_records: collection.create_domain_records,
        triggered_by_user_id: current_user.id
      }

      if collection.file_source?
        args[:uploaded_collection_ids] = [collection.id]
      else
        args[:endpoint_url] = collection.endpoint_url
        args[:collection_ids] = [collection.collection_id]
      end

      args
    end

    def find_projekt
      @projekt = Projekt.find(params[:projekt_id])
    end

    def find_projekt_phase
      if @projekt
        @projekt_phase = @projekt.projekt_phases.find(params[:id])
      else
        @projekt_phase = ProjektPhase.find(params[:id])
      end
    end

    def projekt_phase_params
      filter_empty_registered_address_grouping_restrictions if params.dig(:projekt_phase, :registered_address_grouping_restrictions)

      param_key = @projekt_phase.model_name.param_key
      params.require(param_key).permit(
        :active, :frontend_visibility, :start_date, :end_date,
        :phase_tab_name, :cta_button_name,
        :resource_form_intro, :resource_form_title, :resource_form_title_placeholder,
        :resource_form_description_placeholder, :welcome_text_in_show,
        :labels_name, :sentiments_name,
        :comment_form_title, :comment_form_button,
        :support_button_text, :description,
        :user_status, :age_range_id,
        :geozone_restricted, :registered_address_grouping_restriction,
        :lock_on,
        registered_address_district_ids: [], registered_address_street_ids: [],
        individual_group_value_ids: [], officing_manager_ids: [],
        registered_address_grouping_restrictions: registered_address_grouping_restrictions_params
      )
    end

    def registered_address_grouping_restrictions_params
      ::RegisteredAddress::Grouping.pluck(:key).each_with_object({}) do |key, hash|
        hash[key.to_sym] = []
      end
    end

    def set_back_button_url
      @back_button_url = phases_adm_projekts_projekt_path(@projekt_phase.projekt)
    end

    def filter_empty_registered_address_grouping_restrictions
      grouping_restrictions = params[:projekt_phase][:registered_address_grouping_restrictions]
      return if grouping_restrictions.blank?

      filtered = grouping_restrictions
        .reject { |_, v| v == [""] }
        .as_json
        .each { |_, v| v.reject!(&:blank?) }

      params[:projekt_phase][:registered_address_grouping_restrictions] = filtered
    end

    def create_params
      params.require(:projekt_phase).permit(:projekt_id, :type)
    end

    def criterion_create_params
      params.require(:user_resource_criterion).permit(:name, :description, :ai_instruction)
    end

    def criterion_update_params
      params.require(:user_resource_criterion).permit(:name, :description, :ai_instruction)
    end

    def sanitized_kind_param
      kind = params[:kind].to_s
      return kind if UserResourceCriteria::KINDS.include?(kind)

      nil
    end

    def serialize_criterion(criterion)
      {
        id: criterion.id,
        kind: criterion.kind,
        name: criterion.name,
        description: criterion.description,
        ai_instruction: criterion.ai_instruction,
        position: criterion.position
      }
    end
end
