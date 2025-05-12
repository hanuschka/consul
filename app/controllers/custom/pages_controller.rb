require_dependency Rails.root.join("app", "controllers", "pages_controller").to_s

class PagesController < ApplicationController
  include CommentableActions
  include HasOrders
  include CustomHelper
  include ProposalsHelper
  include Takeable
  include RandomSeed
  include HasEmbeddableShortcodes
  include GuestUsers

  has_orders %w[most_voted newest oldest], only: :show

  before_action :set_random_seed

  def show
    @custom_page = SiteCustomization::Page.published.find_by(slug: params[:id])

    if @custom_page&.landing?
      @content_cards =
        SiteCustomization::ContentCard
          .for_landing_page(@custom_page.id)
          .active
          .to_a
    end

    set_resource_instance
    custom_page_name = Setting.new_design_enabled? ? :custom_page_new : :custom_page

    @custom_page_page_visible =
      @custom_page&.projekt&.preview_code_valid?(params[:preview_code]) ||
      @custom_page&.projekt&.frame_access_code_valid?(params[:frame_code]) ||
      @custom_page&.projekt&.visible_for?(current_user)

    if @custom_page&.landing?
      set_landing_page_topbar_ui_variables(@custom_page)
    end

    if @custom_page.present? && @custom_page.projekt.present? && @custom_page_page_visible
      @projekt = @custom_page.projekt

      if params[:page_ref].present?
        @landing_page =
          @projekt
            .landing_pages
            .find_by(slug: params[:page_ref])

        set_landing_page_topbar_ui_variables(@landing_page)
      end

      if @projekt.feature?("sidebar.show_notification_subscription_toggler")
        @projekt_subscription = ProjektSubscription.find_or_create_by!(projekt: @projekt, user: current_user)
      end

      if @projekt.projekt_phases.active.any?
        @default_projekt_phase = get_default_projekt_phase(params[:projekt_phase_id])
        @projekt_phase = @default_projekt_phase
        params[:projekt_phase_id] = @default_projekt_phase.id
        params[:projekt_id] ||= @projekt.id
        send("set_#{@default_projekt_phase.name}_footer_tab_variables")
      end

      @cards = @custom_page.cards

      @custom_page.content = process_shortcodes_for(
        obj: @custom_page,
        attr: :content,
        projekt: @projekt,
      )

      if Setting["extended_feature.gdpr.two_click_iframe_solution"].present? &&
          @custom_page.content.include?("</iframe>")
        @custom_page.content = process_iframe_embeds(@custom_page.content)
      end

      render action: custom_page_name

    elsif @custom_page.present? && @custom_page.projekt.present?
      @individual_group_value_names = @custom_page.projekt.individual_group_values.pluck(:name)
      render "custom/pages/forbidden", layout: false

    elsif @custom_page.present?
      @cards = @custom_page.cards
      render action: custom_page_name

    else
      render action: params[:id]
    end
  rescue ActionView::MissingTemplate
    head :not_found, content_type: "text/html"
  end

  def projekt_phase_footer_tab
    @projekt_phase = ProjektPhase.find(params[:projekt_phase_id])
    @projekt = @projekt_phase.projekt

    params[:projekt_phase_id] = @projekt_phase.id
    params[:projekt_id] ||= @projekt.id

    send("set_#{@projekt_phase.name}_footer_tab_variables")

    respond_to do |format|
      format.js { render "pages/projekt_footer/footer_tab" }
      format.csv do
        unless current_user&.administrator?
          redirect_path = page_path(@projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "projekt-footer")
          redirect_to redirect_path and return
        end

        if @projekt_phase.name == "debate_phase"
          send_data CsvServices::DebatesExporter.call(@resources.limit(nil)),
            filename: "debates-#{Time.current.strftime("%d-%m-%Y-%H-%M-%S")}.csv"
        elsif @projekt_phase.name == "proposal_phase"
          send_data CsvServices::ProposalsExporter.call(@resources.limit(nil)),
            filename: "proposals-#{Time.current.strftime("%d-%m-%Y-%H-%M-%S")}.csv"
        end
      end
    end
  end

  def extended_sidebar_map
    @current_projekt = SiteCustomization::Page.find_by(slug: params[:id]).projekt

    respond_to do |format|
      format.js { render "pages/sidebar/extended_map" }
    end
  end

  private

  def set_comment_phase_footer_tab_variables
    @valid_orders = %w[most_voted newest oldest]
    @current_order = @valid_orders.include?(params[:order]) ? params[:order] : @valid_orders.first

    @commentable = @projekt_phase
    @comment_tree = CommentTree.new(@commentable, params[:page], @current_order)
    set_comment_flags(@comment_tree.comments)
  end

  def set_debate_phase_footer_tab_variables
    @valid_orders = Debate.debates_orders(current_user)
    @valid_orders.delete("relevance")
    @current_order = if @valid_orders.include?(params[:order])
                       params[:order]
                     elsif helpers.projekt_feature?(@projekt, "general.set_default_sorting_to_newest") && @valid_orders.include?("created_at")
                       @current_order = "created_at"
                     else
                       Setting["selectable_setting.debates.default_order"]
                     end

    @resources = @projekt_phase.debates.for_public_render

    if params[:search].present?
      @resources = @resources.search(params[:search])
    else
      take_by_projekt_labels
      take_by_sentiment
    end

    @debates = @resources.perform_sort_by(@current_order, session[:random_seed]).page(params[:page]).per(24)
  end

  def set_proposal_phase_footer_tab_variables
    @valid_orders = Proposal.proposals_orders(current_user)
    @valid_orders.delete("archival_date")
    @valid_orders.delete("relevance")
    sort_option = @projekt_phase.setting("selectable_setting.general.default_order")

    @current_order = if @valid_orders.include?(params[:order])
                       params[:order]
                     elsif sort_option.present?
                       @current_order = sort_option.value
                     else
                       Setting["selectable_setting.proposals.default_order"]
                     end

    @resources = @projekt_phase.proposals.includes([:image, :projekt_labels, :translations, author: [:image, :organization], sentiment: [:translations]]).for_public_render

    if params[:search].present?
      @resources = @resources.search(params[:search])
    else
      take_by_projekt_labels
      take_by_sentiment
      take_by_my_posts
    end

    @proposals_coordinates = all_proposal_map_locations(@resources)

    @proposals =
      @resources
        .perform_sort_by(@current_order, session[:random_seed])
        .page(params[:page])

    if helpers.browse_mode_in_projekt_footer_tab?(@projekt_phase)
      @proposals = @proposals.page(params[:resource_browse_mode_page]).per(1)
      @proposal = @proposals.first

      if @proposal.present?
        @comment_tree = CommentTree.new(@proposal, params[:page], "newest")
        set_comment_flags(@comment_tree.comments)
      end
    else
      @proposals = @proposals.per(24)
    end
  end

  def set_voting_phase_footer_tab_variables
    # @valid_filters = %w[all current]
    # @current_filter = @valid_filters.include?(params[:filter]) ? params[:filter] : @valid_filters.first

    @valid_orders = nil

    # @resources = @projekt_phase.polls.for_public_render.send(@current_filter)
    @resources = @projekt_phase.polls.for_public_render.all
    @polls = Kaminari.paginate_array(@resources.sort_for_list).page(params[:page])
  end

  def set_legislation_phase_footer_tab_variables
    @legislation_phase = @projekt_phase
    @current_section = params[:section] || "text"

    @process = @projekt_phase.legislation_process
    @draft_versions_list = @process&.draft_versions&.published

    if params[:text_draft_version_id]
      @draft_version = @draft_versions_list.find(params[:text_draft_version_id])
    else
      @draft_version = @draft_versions_list&.last
    end

    if @current_section == "all_drafts_annotations"
      @annotations = @draft_version.annotations
    end

    if @current_section == "annotations"
      @annotation = Legislation::Annotation.find(params[:annotation_id])

      @commentable = @annotation

      annotations = [@commentable]

      @valid_orders = %w[most_voted newest oldest]
      @current_order = @valid_orders.include?(params[:order]) ? params[:order] : @valid_orders.first

      @comment_tree = MergedCommentTree.new(annotations, params[:page], @current_order)
      set_comment_flags(@comment_tree.comments)
    end
  end

  def set_budget_phase_footer_tab_variables
    @budget = @projekt_phase.budget
    return if @budget.blank?

    @heading = @budget.heading

    @all_resources = []

    @valid_filters = @budget.investments_filters
    params[:filter] ||= "feasible" if @budget.current_phase.kind.in?(["selecting", "valuating"])
    params[:filter] ||= "selected" if @budget.current_phase.kind.in?(["publishing_prices", "balloting", "reviewing_ballots"])
    params[:filter] ||= "winners" if @budget.current_phase.kind == "finished"
    @current_filter = @valid_filters.include?(params[:filter]) ? params[:filter] : "all"

    @valid_orders = Budget::Investment::DEFAULT_ORDERS.dup
    @valid_orders.delete("total_votes") unless @budget.current_phase.kind == "selecting"
    @valid_orders.delete("ballot_line_weight") unless @budget.current_phase.kind == "balloting"

    sort_option = @projekt_phase.setting("selectable_setting.general.default_order")

    @current_order =
      if @valid_orders.include?(params[:order])
        params[:order]
      elsif sort_option.present? || @valid_orders.include?(sort_option.value)
        @current_order = sort_option.value
      else
        @valid_orders.first
      end

    if @budget.current_phase.kind == "finished"
      if @budget.voting_style == "distributed"
        @current_order = "ballot_line_weight"
      elsif @budget.voting_style == "approval" || @budget.voting_style == "knapsack"
        @current_order = "ballots"
      end
    end

    params[:section] ||= "results" if @budget.current_phase.kind == "finished"

    # con-1036
    if @budget.current_phase.kind == "publishing_prices" && @budget.show_results_after_first_vote?
      @current_filter = "selected"
    end
    # con-1036

    if params[:section] == "results" && can?(:read_results, @budget)
      @investments = Budget::Result.new(@budget, @budget.heading).investments
    elsif params[:section] == "stats" && can?(:read_stats, @budget)
      params["stats_section"] ||= "accepting" if @budget.current_phase.kind.in? %w[accepting reviewing]
      params["stats_section"] ||= "selecting" if @budget.current_phase.kind.in? %w[selecting valuating publishing_prices]
      params["stats_section"] ||= "balloting" if @budget.current_phase.kind.in? %w[balloting]

      if params["stats_section"].in? %w[accepting reviewing selecting valuating publishing_prices balloting]
        @stats = Budget::PhaseStats.new(@budget, params["stats_section"])
      else
        @stats = Budget::Stats.new(@budget)
      end
      @investments = @budget.investments
    else
      query = Budget::Ballot.where(user: current_user, budget: @budget)
      @ballot = @budget.balloting? ? query.first_or_create!(conditional: ballot_conditional?) : query.first_or_initialize(conditional: ballot_conditional?)

      @resources = @budget.investments

      if params[:search].present?
        @resources = @resources.search(params[:search])
      else
        take_by_projekt_labels
        take_by_sentiment
      end

      @investments = @resources.send(@current_filter)
      @investment_ids = @investments.ids
      @investment_coordinates = MapLocation.where(investment_id: @investments).map(&:json_data)
      @investments = @investments.perform_sort_by(@current_order, session[:random_seed]).page(params[:page]).per(24)
    end

    if helpers.browse_mode_in_projekt_footer_tab?(@projekt_phase)
      @investments = @investments.page(params[:resource_browse_mode_page]).per(1)
      @investment = @investments.first

      if @investment.present?
        @comment_tree = CommentTree.new(@investment, params[:page], "newest")
        set_comment_flags(@comment_tree.comments)
      end
    end
  end

  def set_milestone_phase_footer_tab_variables
    @current_milestone = @projekt_phase.milestones
                                 .where("publication_date < ?", Time.zone.today)
                                 .order(publication_date: :desc)
                                 .first

    order_newest = @projekt_phase.settings.find_by(key: "feature.general.newest_first").value.present?
    @milestones_publication_date_order = order_newest ? :desc : :asc
  end

  def set_projekt_notification_phase_footer_tab_variables
    @projekt_notifications = @projekt_phase.projekt_notifications
  end

  def set_newsfeed_phase_footer_tab_variables
    @rss_id = @projekt_phase.settings.find_by(key: "option.general.newsfeed_id").value
    @rss_type = @projekt_phase.settings.find_by(key: "option.general.newsfeed_type").value
  end

  def set_event_phase_footer_tab_variables
    @valid_filters = %w[all incoming past]
    @current_filter = @valid_filters.include?(params[:filter]) ? params[:filter] : "all"
    order = @projekt_phase.feature?("general.reverse_order_for_incoming_events") ? :desc : :asc

    @projekt_events = @projekt_phase.projekt_events
                                    .send("sort_by_#{@current_filter}")
                                    .reorder(datetime: order)
                                    .page(params[:page])
  end

  def set_question_phase_footer_tab_variables
    projekt_questions = @projekt_phase.questions.root_questions

    if @projekt_phase.question_list_enabled?
      @projekt_questions = projekt_questions
    else
      @projekt_question = projekt_questions.first
      @commentable = @projekt_question

      @valid_orders = %w[most_voted newest oldest]
      @current_order = @valid_orders.include?(params[:order]) ? params[:order] : @valid_orders.first

      @comment_tree = CommentTree.new(@commentable, params[:page], @current_order)

      if @commentable.present?
        set_comment_flags(@comment_tree.comments)
      end

      @projekt_question_answer = @projekt_question&.answer_for_user(current_user) || ProjektQuestionAnswer.new
    end
  end

  def set_argument_phase_footer_tab_variables
    @projekt_arguments_pro = @projekt_phase.projekt_arguments.pro.order(created_at: :desc)
    @projekt_arguments_cons = @projekt_phase.projekt_arguments.cons.order(created_at: :desc)
  end

  def set_livestream_phase_footer_tab_variables
    @all_livestreams = @projekt_phase.projekt_livestreams.order(created_at: :desc)
    @current_projekt_livestream = @all_livestreams.first
    @other_livestreams = @all_livestreams.select(:id, :title)
  end

  def set_formular_phase_footer_tab_variables
    @formular = @projekt_phase.formular

    if params[:token].present?
      @recipient = FormularFollowUpLetterRecipient.find_by(subscription_token: params[:token])
      return unless @recipient.present? && @recipient.formular.id == @formular.id

      @formular_fields = @formular.formular_fields.follow_up.each(&:set_custom_attributes)
      @formular_answer = @recipient.formular_answer
      @formular_answer.answer_errors ||= {}
    elsif !@formular.past_cutoff_date?
      @formular_fields = @formular.formular_fields.primary.each(&:set_custom_attributes)
      @formular_answer = @formular.formular_answers.new
      @formular_answer.answer_errors ||= {}
    end
  end

  def get_default_projekt_phase(default_phase_id = nil)
    default_phase_id ||= ProjektSetting.find_by(projekt: @projekt, key: "projekt_custom_feature.default_footer_tab").value
    @default_projekt_phase = ProjektPhase.find_by(id: default_phase_id) || @projekt.projekt_phases.active.first
  end

  def set_resources(resource_model)
    @resources = resource_model.all

    @resources = @current_order == "recommendations" && current_user.present? ? @resources.recommendations(current_user) : @resources.for_render
    @resources = @resources.search(@search_terms) if @search_terms.present?
    @resources = @resources.filter_by(@advanced_search_terms)
  end

  def resource_model
    SiteCustomization::Page
  end

  def resource_name
    "page"
  end

  def ballot_conditional?
    return false unless current_user.present?

    @projekt_phase.user_status == "verified" &&
      current_user.verified_at.nil? &&
      helpers.projekt_phase_feature?(@projekt_phase, "resource.conditional_balloting")
  end
end
