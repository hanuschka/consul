class Adm::Projekts::PhasesController < Adm::Projekts::BaseController
  before_action :find_projekt, only: [:new, :create]
  before_action :find_projekt_phase, except: [:new, :create]
  before_action :set_back_button_url, except: [:new, :create, :update, :toggle_active, :toggle_frontend_visibility, :update_age_ranges_for_stats]

  def new
    authorize [:adm, :projekts, ProjektPhase], :create?
    @phase_types = ProjektPhase::PROJEKT_PHASES_TYPES

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt.page.title },
      { name: t("adm.projekts.phases.index.title"), url: phases_adm_projekts_projekt_path(@projekt) },
      { name: t(".title") }
    ]
  end

  def create
    authorize [:adm, :projekts, ProjektPhase], :create?
    @projekt_phase = ProjektPhase.new(create_params.merge(active: true))

    if @projekt_phase.save
      redirect_to phases_adm_projekts_projekt_path(@projekt), notice: t(".success")
    else
      redirect_to new_adm_projekts_projekt_phase_path(@projekt), alert: @projekt_phase.errors.full_messages.join(", ")
    end
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
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def naming
    authorize_phase(:update?)
    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def restrictions
    authorize_phase(:update?)
    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def toggle_active
    authorize_phase(:update?)
    @projekt_phase.update(active: !@projekt_phase.active)
  end

  def toggle_frontend_visibility
    authorize_phase(:update?)
    @projekt_phase.update(frontend_visibility: !@projekt_phase.frontend_visibility)
  end

  def general_settings
    authorize_phase(:update?)
    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def form_author
    authorize_phase(:update?)
    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def user_functions
    authorize_phase(:update?)
    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def proposals
    authorize_phase(:update?)
    base_scope = @projekt_phase.proposals.with_hidden
    @pagy, @proposals = pagy(ProposalsQuery.call(base_scope, params))

    @moderation_header_options = { filter_options: moderation_filter_options }

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def comments
    authorize_phase(:update?)
    base_scope = comments_for_phase
    @pagy, @comments = pagy(CommentsQuery.call(base_scope, params))

    @moderation_header_options = { filter_options: moderation_filter_options }

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def user_resource_criteria
    authorize_phase(:update?)
    @criteria = @projekt_phase.user_resource_criteria

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def proposal_criteria
    authorize_phase(:update?)
    @criteria = @projekt_phase.proposal_criteria

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
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
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
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
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def budget_investments
    authorize_phase(:update?)
    @budget = @projekt_phase.budget
    base_scope = BudgetInvestmentsQuery.call(@budget.investments.with_hidden.order(id: :desc), params)

    respond_to do |format|
      format.html do
        @pagy, @investments = pagy(base_scope)

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
          { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
          { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t(".title") }
        ]
      end
      format.csv do
        send_data CsvServices::BudgetInvestmentsExporter.call(base_scope, request.host),
                  filename: "budget_investments-#{@projekt_phase.id}-#{Time.zone.today}.csv"
      end
    end
  end

  def poll_questions
    authorize_phase(:update?)
    @poll = @projekt_phase.poll
    @questions = @poll.questions.root_questions.where(context_id: nil)

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def formular
    authorize_phase(:update?)
    @formular = @projekt_phase.formular
    @formular_fields_primary = @formular.formular_fields.primary
    @formular_fields_follow_up = @formular.formular_fields.follow_up

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def formular_answers
    authorize_phase(:update?)
    @formular = @projekt_phase.formular
    @formular_fields = @formular.formular_fields
    @formular_answers = @formular.formular_answers
    @formular_follow_up_letters = @formular.formular_follow_up_letters

    respond_to do |format|
      format.html do
        @breadcrumbs = [
          { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
          { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t(".title") }
        ]
      end
      format.csv do
        send_data CsvServices::FormularAnswersExporter.call(@formular),
          filename: "formular_answers-#{@formular.id}-#{Time.zone.today}.csv"
      end
    end
  end
  def milestones
    authorize_phase(:update?)
    @milestones = @projekt_phase.milestones.order_by_publication_date

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def progress_bars
    authorize_phase(:update?)
    @progress_bars = @projekt_phase.progress_bars

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end
  def legislation_process_draft_versions
    authorize_phase(:update?)
    @process = @projekt_phase.legislation_process

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end
  def map
    authorize_phase(:update?)
    @projekt_phase.copy_map_settings_from_projekt unless @projekt_phase.map_location.present?

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end
  def projekt_point_of_interest_categories
    authorize_phase(:update?)
    @categories = @projekt_phase.projekt_point_of_interest_categories.ordered

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def projekt_point_of_interest_pins
    authorize_phase(:update?)
    @pagy, @pins = pagy(@projekt_phase.projekt_point_of_interest_pins.ordered)

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def map_resources_overview
    authorize_phase(:update?)

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def projekt_labels
    authorize_phase(:update?)
    @projekt_labels = @projekt_phase.projekt_labels

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def sentiments
    authorize_phase(:update?)
    @sentiments = @projekt_phase.sentiments

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def officing_managers
    authorize_phase(:update?)
    @officing_managers = OfficingManager.all

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
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
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  def age_ranges_for_stats
    authorize_phase(:update?)
    @age_ranges = AgeRange.for_stats

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
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

  # TODO: implement ai_settings logic
  def ai_settings
    authorize_phase(:update?)

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end
  def projekt_notifications
    authorize_phase(:update?)
    @projekt_notifications = @projekt_phase.projekt_notifications.order(created_at: :desc)

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end
  def projekt_events
    authorize_phase(:update?)
    @projekt_events = @projekt_phase.projekt_events.order(datetime: :desc)

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end
  def projekt_livestreams
    authorize_phase(:update?)
    @projekt_livestreams = @projekt_phase.projekt_livestreams

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end
  def projekt_questions
    authorize_phase(:update?)
    @pagy, @projekt_questions = pagy(@projekt_phase.questions.order(id: :desc))

    @breadcrumbs = [
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
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
      { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
      { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
      { name: @projekt_phase.title },
      { name: t(".title") }
    ]
  end

  private

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
end
