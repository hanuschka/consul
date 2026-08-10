require_dependency Rails.root.join("app", "controllers", "proposals_controller").to_s

class ProposalsController
  include ProposalsHelper
  include ProjektControllerHelper
  include Takeable
  include ProjektLabelAttributes
  include RandomSeed
  include GuestUsers
  include CustomHelper
  include LandingPageResolvable
  include OnBehalfOfAccountLinking

  MAP_PINS_LAZY_LOAD_THRESHOLD = 50

  # A page shows 24 cards; the cap only stops a hand-rolled request from asking us to re-render
  # every proposal in the phase.
  MAX_REFRESHED_CARDS = 50

  before_action :set_projekts_for_selector, only: [:new, :edit, :create, :update]
  before_action :set_random_seed, only: :index
  prepend_before_action :load_draft_proposal_for_admin, only: :show

  def index_customization
    resolve_landing_page_from_slug

    if params[:order].nil?
      @current_order = Setting["selectable_setting.proposals.default_order"]
    end
    @resource_name = "proposal"

    @geozones = Geozone.all
    @districts = RegisteredAddress::District.all.sort_by(&:name_for_display)
    @selected_geozone_affiliation = params[:geozone_affiliation] || "all_resources"
    @affiliated_districts = (params[:affiliated_districts] || "").split(",").map(&:to_i)
    @affiliated_geozones = (params[:affiliated_geozones] || "").split(",").map(&:to_i)
    @selected_geozone_restriction = params[:geozone_restriction] || "no_restriction"
    @restricted_geozones = (params[:restricted_geozones] || "").split(",").map(&:to_i)

    discard_draft
    discard_archived
    load_retired
    load_selected
    load_featured
    remove_archived_from_order_links

    @scoped_projekt_ids = Proposal.scoped_projekt_ids_for_index(current_user)

    if @landing_page.present?
      @scoped_projekt_ids = @scoped_projekt_ids & landing_page_scoped_projekt_ids
    end
    @top_level_active_projekts = Projekt.top_level.current.where(id: @scoped_projekt_ids)
    @top_level_archived_projekts = Projekt.top_level.expired.where(id: @scoped_projekt_ids)

    related_projekt_ids = @resources.joins(:projekt_phase).pluck("projekt_phases.projekt_id").uniq
    related_projekts = Projekt.where(id: related_projekt_ids)
    @categories = Tag.category.joins(:taggings)
      .where(taggings: { taggable_type: "Projekt", taggable_id: related_projekt_ids }).order(:name).uniq
    if params[:sdg_goals].present?
      sdg_goal_ids = SDG::Goal.where(code: params[:sdg_goals].split(",")).ids
      @sdg_targets = SDG::Target.where(goal_id: sdg_goal_ids).joins(:relations)
        .where(sdg_relations: { relatable_type: "Projekt", relatable_id: related_projekt_ids })
    end

    @resources =
      @resources
        .where(admin_accepted: true)
        .meets_minimum_supports
        .by_projekt_id(@scoped_projekt_ids)

    @all_resources = @resources

    unless params[:search].present?
      take_by_my_posts
      take_by_geozone_affiliations
      take_by_geozone_restrictions
      take_by_projekts(@scoped_projekt_ids)
    end

    @proposals_map_pin_count =
      proposal_map_pin_count_up_to(@resources, MAP_PINS_LAZY_LOAD_THRESHOLD)

    @proposals_coordinates =
      if @proposals_map_pin_count <= MAP_PINS_LAZY_LOAD_THRESHOLD
        all_proposal_map_locations(@resources)
      else
        []
      end

    @proposals = @resources.perform_sort_by(@current_order, session[:random_seed]).page(params[:page]).per(24).with_index_card_associations

    respond_to do |format|
      format.html do
        if Setting.new_design_enabled?
          render :index_new
        else
          render :index
        end
      end

      format.json do
        render json: JSON.generate(
          MapLocation.flatten_feature_collections(
            all_proposal_map_locations(@resources)
          )
        )
      end

      format.csv do
        redirect_to proposals_path and return unless current_user&.administrator?

        send_data CsvServices::ProposalsExporter.call(@resources.limit(nil)),
          filename: "proposals-#{Time.current.strftime("%d-%m-%Y-%H-%M-%S")}.csv"
      end
    end
  end

  def new
    @projekt_phase = ProjektPhase::ProposalPhase.find_by(id: params[:projekt_phase_id])

    if @projekt_phase.blank? && Projekt.top_level.selectable_in_selector("proposals", current_user).empty?
      redirect_to proposals_path
    elsif @projekt_phase.present? && !@projekt_phase.selectable_by?(current_user)
      redirect_to page_path(@projekt_phase.projekt.page.slug,
                            projekt_phase_id: @projekt_phase.id,
                            anchor: "filter-subnav")
    end

    @resource = resource_model.new(projekt_phase: @projekt_phase)
    set_geozone
    set_resource_instance
    @selected_projekt = Projekt.find(params[:projekt_id]) if params[:projekt_id]

    if @projekt_phase.present?
      resolve_landing_page_for_projekt(@projekt_phase.projekt)
    end
  end

  def edit
    @selected_projekt = @proposal&.projekt_phase&.projekt

    params[:projekt_phase_id] = @proposal&.projekt_phase&.id
    params[:projekt_id] = @selected_projekt&.id

    if @selected_projekt.present?
      resolve_landing_page_for_projekt(@selected_projekt)
    end
  end

  def update
    if resource.update(proposal_params)
      NotificationServices::NewProposalNotifier.new(resource.id).call if resource.published?
      redirect_to resource, notice: t("flash.actions.update.#{resource_name.underscore}")
    else
      render :edit
    end
  end

  def create
    @proposal = Proposal.new(proposal_params.merge(author: current_user))
    @projekt_phase = @proposal.projekt_phase
    @proposal.admin_accepted = false if @projekt_phase.feature?("general.require_admin_acceptance")

    if @proposal.valid? && link_on_behalf_of_account(@proposal) && @proposal.save
      if params[:save_draft].present?
        redirect_to proposal_path(@proposal),
          notice: I18n.t("flash.actions.create.proposal")

      else
        @proposal.publish

        Mailer.proposal_created(@proposal).deliver_later

        redirect_to proposal_path(@proposal), notice: t("proposals.notice.published")
      end
    else
      params[:projekt_phase_id] = @proposal&.projekt_phase&.id
      params[:projekt_id] = @proposal&.projekt_phase&.projekt&.id

      if @projekt_phase.present?
        resolve_landing_page_for_projekt(@projekt_phase.projekt)
      end

      render :new
    end
  end

  def publish
    @proposal.publish

    if @proposal.projekt_phase.active?
      redirect_to page_path(
        @proposal.projekt_phase.projekt.page.slug,
        anchor: "filter-subnav",
        projekt_phase_id: @proposal.projekt_phase.id,
        order: "created_at"), notice: t("proposals.notice.published")
    else
      redirect_to proposals_path(order: "created_at"), notice: t("proposals.notice.published")
    end
  end

  def show
    super
    @projekt = @proposal.projekt_phase&.projekt

    if @projekt.nil?
      redirect_to proposals_path

      return
    end

    if !@proposal.admin_accepted? && !allowed_to_preview_pending?
      redirect_to proposals_path, notice: t("proposals.notice.pending_acceptance") and return
    end

    # @notifications = @proposal.notifications
    @notifications = @proposal.notifications.not_moderated
    @milestones = @proposal.milestones

    @related_contents = Kaminari.paginate_array(@proposal.relationed_contents)
                                .page(params[:page]).per(5)

    @affiliated_districts = (params[:affiliated_districts] || "").split(",").map(&:to_i)
    @restricted_geozones = (params[:restricted_geozones] || "").split(",").map(&:to_i)

    resolve_landing_page_for_projekt(@projekt)

    if request.path != proposal_path(@proposal)
      redirect_to proposal_path(@proposal), status: :moved_permanently

    elsif !@projekt.visible_for?(current_user)
      @individual_group_value_names = @projekt.individual_group_values.pluck(:name)
      render "custom/pages/forbidden", layout: false

    elsif Setting.new_design_enabled?
      @proposal.description = process_oembeds(@proposal.description)
      render :show_new

    else
      render :show
    end
  end

  def vote
    if up_and_down_voting_enabled?
      @voted = @proposal.register_vote(voting_user, params[:value])
    else
      @follow = Follow.find_or_create_by!(user: voting_user, followable: @proposal)
      @voted = @proposal.register_vote(voting_user, "yes")
    end

    prepare_cards_to_refresh
  end

  def unvote
    @follow = Follow.find_by(user: voting_user, followable: @proposal)

    @follow.destroy! if @follow

    @voted = !@proposal.unvote_by(voting_user)

    prepare_cards_to_refresh
  end

  def created
    @resource_name = "proposal"
    @affiliated_districts = []
    @restricted_geozones = []
  end

  def flag
    flag = Flag.flag(current_user, @proposal)
    Flags::NotifyModerationJob.perform_later(flag.id) if flag
    @proposal.update!(ignored_flag_at: nil)

    redirect_to @proposal
  end

  def unflag
    Flag.unflag(current_user, @proposal)
    redirect_to @proposal
  end

  private

    # A proposal awaiting moderation is hidden from the portal, but not from the
    # person who wrote it: they are the one party who already knows it exists and
    # has the most reason to check what was submitted. This is the only way a
    # WhatsApp submitter can see their own pending proposal at all — the chat
    # sends them the link, and it stops being a dead end once they are logged in.
    #
    # Acceptance is gated here rather than in CanCan, so the signed link from an
    # on-behalf-of account mail has to be admitted here too — otherwise that mail
    # sends its recipient to a page that turns them away. :preview rather than
    # :show because every proposal is :read-able to everyone, so only an action
    # nothing else grants can single out the record that link names.
    def allowed_to_preview_pending?
      return true if current_user&.has_pm_permission_to?(:manage, @projekt)
      return true if can?(:preview, @proposal)

      current_user.present? && @proposal.author_id == current_user.id
    end

    # The support and withdraw buttons carry the ids of the cards that were on screen, so the
    # response can refresh all of them. Only the clicked card is re-rendered otherwise, and
    # crossing the phase's supports limit changes what every other card in the phase shows.
    #
    # Mirrors Budgets::Ballot::LinesController#load_investments, which solves the same
    # interdependency for ballot lines. Scoped to the phase the vote happened in, both because
    # that is the only phase whose cards can have changed and because it keeps a caller from
    # asking for arbitrary proposals. Phases without a supports limit keep re-rendering a single
    # card, as they did before the limit existed.
    #
    # Runs after the vote is written, never as a before_action: the answers being re-rendered
    # depend on it. All the cards reach the same ProjektPhase instance, so resetting its cache
    # once is enough for the whole response.
    def prepare_cards_to_refresh
      projekt_phase = @proposal.projekt_phase
      projekt_phase&.reset_permission_problem_cache!

      # The card sends this back so the re-render keeps the share popup it had. Only list cards
      # carry one; the show page renders the same component without it.
      @show_share_popup = params[:show_share_popup] == "true"

      return if params[:proposals_ids].blank?
      return unless projekt_phase&.supports_limit_applies?

      @proposal_ids = Array(params[:proposals_ids]).first(MAX_REFRESHED_CARDS)
      @proposals = projekt_phase.proposals
                                .where(id: @proposal_ids)
                                .where.not(id: @proposal.id)
                                .includes(:votes_for)
    end

    def load_draft_proposal_for_admin
      return if current_user.blank?
      return if !current_user.administrator?

      proposal = Proposal.unscoped.find_by(id: params[:id])

      if proposal&.draft
        @proposal = proposal
      end
    end

    def proposal_params
      attributes = [:id, :video_url, :responsible_name, :tag_list, :on_behalf_of,
                    :on_behalf_of_company_name, :on_behalf_of_email,
                    :geozone_id, :projekt_id, :projekt_phase_id, :related_sdg_list,
                    :terms_of_service, :terms_data_storage, :terms_data_protection, :terms_general, :resource_terms,
                    :sentiment_id,
                    projekt_label_ids: [],
                    image_attributes:,
                    documents_attributes: [:id, :title, :attachment, :cached_attachment,
                                           :user_id, :_destroy],
                    map_location_attributes:]
      translations_attributes = translation_params(Proposal, except: :retired_explanation)
      params.require(:proposal).permit(attributes, translations_attributes)
    end

    def voting_user
      return current_user unless params[:offline_user_id].present?

      current_user.officing_manager? ? User.find(params[:offline_user_id]) : current_user
    end

    def up_and_down_voting_enabled?
      @proposal.projekt_phase.feature?("resource.enable_up_and_down_voting")
    end
end
