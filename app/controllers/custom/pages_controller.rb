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
  include LandingPageResolvable

  helper DeficiencyReportsHelper

  has_orders %w[most_voted newest oldest], only: :show

  before_action :set_random_seed

  def show
    @custom_page = SiteCustomization::Page.find_by(slug: params[:id])

    if @custom_page.present? && !@custom_page.published? && !draft_page_previewable?(@custom_page)
      @custom_page = nil
    end

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
      @custom_page&.projekt&.visible_for?(current_user)

    if @custom_page&.landing?
      set_landing_page_topbar_ui_variables(@custom_page)
    end

    if current_user.present?
      @namespace =
        if current_user.administrator?
          :admin
        elsif @custom_page.present? && current_user.projekt_manager?(@custom_page.projekt)
          :projekt_management
        end
    end

    if @custom_page.present? && @custom_page.projekt.present? && @custom_page_page_visible
      @projekt = @custom_page.projekt

      resolve_landing_page_for_projekt(@projekt)

      if @projekt.feature?("sidebar.show_notification_subscription_toggler")
        @projekt_subscription = ProjektSubscription.find_or_create_by!(projekt: @projekt, user: current_user)
      end

      if @projekt.projekt_phases.active.frontend_visible.any? || helpers.show_admin_controls_for_projekt?(@projekt)
        @default_projekt_phase = get_default_projekt_phase(params[:projekt_phase_id])

        if @default_projekt_phase.present?
          @projekt_phase = @default_projekt_phase

          params[:projekt_phase_id] = @default_projekt_phase.id
          params[:projekt_id] ||= @projekt.id
          send("set_#{@default_projekt_phase.name}_footer_tab_variables")
        end
      end

      @cards = @custom_page.cards

      @custom_page.content = process_shortcodes(@custom_page.content, projekt: @projekt)

      if Setting["extended_feature.gdpr.two_click_iframe_solution"].present? &&
          @custom_page.content&.include?("</iframe>")
        @custom_page.content = process_iframe_embeds(@custom_page.content)
      end

      @custom_page.content = process_oembeds(@custom_page.content)

      render action: custom_page_name

    elsif @custom_page.present? && @custom_page.projekt.present?
      @individual_group_value_names = @custom_page.projekt.individual_group_values.pluck(:name)
      render "custom/pages/forbidden", layout: false

    elsif @custom_page.present?
      @cards = @custom_page.cards
      render action: custom_page_name

    elsif params[:id].to_s.match?(%r{\A[a-z0-9]+(?:[_\-/][a-z0-9]+)*\z}i)
      render action: params[:id]
    else
      head :not_found, content_type: "text/html"
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
        unless current_user&.has_pm_permission_to?(:manage, @projekt)
          redirect_path = page_path(@projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "projekt-footer")
          redirect_to redirect_path and return
        end

        if @projekt_phase.name == "debate_phase"
          send_data CsvServices::DebatesExporter.call(@resources.limit(nil)),
            filename: "debates-#{Time.current.strftime("%d-%m-%Y-%H-%M-%S")}.csv"
        elsif @projekt_phase.name == "proposal_phase"
          send_data CsvServices::ProposalsExporter.call(@resources.limit(nil)),
            filename: "proposals-#{Time.current.strftime("%d-%m-%Y-%H-%M-%S")}.csv"
        elsif @projekt_phase.name == "budget_phase"
          send_data CsvServices::BudgetInvestmentsExporter.call(@investments.limit(nil), request.base_url),
            filename: "budget_investments-#{Time.current.strftime("%d-%m-%Y-%H-%M-%S")}.csv"
        end
      end
    end
  end

  private

    def set_comment_phase_footer_tab_variables
      @valid_orders = %w[most_voted newest oldest]
      @current_order = @valid_orders.include?(params[:order]) ? params[:order] : @valid_orders.first

      @commentable = @projekt_phase

      if params[:section].in?(["key_metrics", "analysis", "evaluation", "ai_evaluation"]) && can?(:read_stats, @projekt_phase) && can_view_stats_section?(params[:section], @projekt_phase)
        @stats = @projekt_phase
      else
        @comment_tree = CommentTree.new(@commentable, params[:page], @current_order)
        set_comment_flags(@comment_tree.comments)
      end
    end

    def set_debate_phase_footer_tab_variables
      @valid_orders = Debate.debates_orders(current_user)
      @valid_orders.delete("relevance")
      @current_order = if @valid_orders.include?(params[:order])
                         params[:order]
                       elsif helpers.projekt_feature?(@projekt,
  "general.set_default_sorting_to_newest") && @valid_orders.include?("created_at")
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
      auto_sign_in_guest_for(@projekt_phase)
      @valid_orders = Proposal.proposals_orders(current_user)
      @valid_orders.delete("archival_date")
      @valid_orders.delete("relevance")
      sort_option = @projekt_phase.setting("selectable_setting.general.default_order")

      @current_order = if @valid_orders.include?(params[:order])
                         params[:order]
                       elsif sort_option.present? && @valid_orders.include?(sort_option.value)
                         sort_option.value
                       else
                         Setting["selectable_setting.proposals.default_order"]
                       end

      min_supports = @projekt_phase.settings
                                   .find_by(key: "option.resource.minimum_supports_to_show")
                                   &.value.to_i

      @resources = @projekt_phase.proposals
                                 .base_selection
                                 .with_min_supports(min_supports)

      if params[:section].in?(["key_metrics", "analysis", "evaluation", "ai_evaluation"]) && can?(:read_stats, @projekt_phase) && can_view_stats_section?(params[:section], @projekt_phase)
        @stats = @projekt_phase
      else
        if params[:search].present?
          @resources = @resources.search(params[:search])
        else
          take_by_projekt_labels
          take_by_sentiment
          take_by_my_posts
        end

        @proposals_map_pin_count =
          proposal_map_pin_count_up_to(@resources, Shared::MapComponent::LAZY_LOAD_THRESHOLD,
                                       @projekt_phase)

        if @proposals_map_pin_count <= Shared::MapComponent::LAZY_LOAD_THRESHOLD
          @proposals_coordinates = all_proposal_map_locations(@resources)
          @proposals_coordinates += MasterportalPin.standalone_features_for_phase(@projekt_phase)
        else
          @proposals_coordinates = []
        end

        @proposals =
          @resources
            .perform_sort_by(@current_order, session[:random_seed])
            .page(params[:page])
            .includes([:image, :projekt_labels, :translations, :community, author: [:image, :organization], sentiment: [:translations], projekt_phase: [:settings, :projekt_labels, :geozone_restrictions, { projekt: [:translations, { page: :translations }] }]])

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
    end

    def set_voting_phase_footer_tab_variables
      # @valid_filters = %w[all current]
      # @current_filter = @valid_filters.include?(params[:filter]) ? params[:filter] : @valid_filters.first

      @valid_orders = nil

      if !params[:section].in?(%w[evaluation ai_evaluation poll_stats])
        # @resources = @projekt_phase.polls.for_public_render.send(@current_filter)
        @resources = @projekt_phase.polls.for_public_render.all
        @polls = Kaminari.paginate_array(@resources.sort_for_list).page(params[:page])
      end

      set_voting_phase_evaluation_variables
    end

    def set_voting_phase_evaluation_variables
      if params[:section] == "poll_stats" &&
          helpers.footer_evaluation_tab_available?(@projekt_phase, "poll_stats")
        @poll_stats_entries = @projekt_phase.polls.for_public_render.order(id: :desc).map do |poll|
          { poll: poll, stats: Poll::Stats.new(poll) }
        end
      end

      if params[:section] == "evaluation" &&
          helpers.footer_render_frozen_evaluation?(@projekt_phase)
        @live_phase_stats = voting_phase_live_stats

        phase_polls = @projekt_phase.polls.for_public_render.limit(2).to_a
        @frontend_answer_poll = phase_polls.first if phase_polls.one?
      end
    end

    def voting_phase_live_stats
      if helpers.footer_admin_or_projekt_manager?
        cached_voting_phase_live_stats(
          "footer_live_phase_stats/admin/#{@projekt_phase.id}",
          ProjektPhaseSettingsHelper::FOOTER_LIVE_STATS_ADMIN_TTL
        )
      else
        cached_voting_phase_live_stats(
          "footer_live_phase_stats/#{@projekt_phase.id}",
          ProjektPhaseSettingsHelper::FOOTER_LIVE_STATS_TTL
        )
      end
    end

    def cached_voting_phase_live_stats(cache_key, ttl)
      cached_stats = Rails.cache.read(cache_key)
      return cached_stats if cached_stats.present?

      stats = compute_voting_phase_live_stats

      if stats.present?
        Rails.cache.write(cache_key, stats, expires_in: ttl)
      end

      stats
    end

    def compute_voting_phase_live_stats
      ProjektEvaluations::AggregateStatistics
        .new(@projekt)
        .call_for_phase(@projekt_phase)
        &.dig(:stats)
        &.deep_stringify_keys
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
      auto_sign_in_guest_for(@projekt_phase)
      @budget = @projekt_phase.budget
      return if @budget.blank?

      @heading = @budget.heading

      @all_resources = []

      @valid_filters = @budget.investments_filters
      params[:filter] ||= "feasible" if @budget.current_phase.kind.in?(["selecting"])
      params[:filter] ||= "preselected" if @budget.current_phase.kind.in?(["valuating"])
      params[:filter] ||= "selected" if @budget.current_phase.kind.in?(["publishing_prices", "balloting",
  "reviewing_ballots"])
      params[:filter] ||= "winners" if @budget.current_phase.kind == "finished"
      @current_filter = @valid_filters.include?(params[:filter]) ? params[:filter] : "all"

      @valid_orders = @projekt_phase.investment_orders
      @valid_orders.delete("total_votes") unless @budget.current_phase.kind.in?(["selecting", "valuating",
  "publishing_prices"])
      @valid_orders.delete("ballot_line_weight") unless @budget.current_phase.kind == "balloting" && !@projekt_phase.setting("feature.resource.hide_ballots_count").enabled?

      sort_option = @projekt_phase.setting("selectable_setting.general.default_order")

      @current_order =
        if @valid_orders.include?(params[:order])
          params[:order]
        elsif sort_option.present? && @valid_orders.include?(sort_option.value)
          sort_option.value
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
      elsif params[:section].in?(["key_metrics", "analysis", "evaluation", "ai_evaluation"]) && can?(:read_stats, @budget) && can_view_stats_section?(params[:section], @projekt_phase)
        @stats = @projekt_phase
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
        @investment_coordinates = MapLocation.with_investment_associations
  .where(mappable_id: @investment_ids).map(&:features_json_data)
        @investment_coordinates += MasterportalPin.standalone_features_for_phase(@projekt_phase)
        @investments = @investments.perform_sort_by(@current_order,
  session[:random_seed]).page(params[:page]).per(24)
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

    def set_point_of_interest_phase_footer_tab_variables
      auto_sign_in_guest_for(@projekt_phase)

      @pin_coordinates = MapData::PointOfInterestPhase.call(
        projekt_phase: @projekt_phase,
        category_ids: params[:category_ids]
      )
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
    end

    def set_question_phase_footer_tab_variables
      auto_sign_in_guest_for(@projekt_phase)

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

    def set_mitmachbox_phase_footer_tab_variables
    end

    def set_iframe_phase_footer_tab_variables
      @iframe_url = @projekt_phase.settings.find { |s| s.key == "option.general.iframe_url" }.value
      @iframe_width = @projekt_phase.settings.find { |s| s.key == "option.general.iframe_width" }.value
      @iframe_height = @projekt_phase.settings.find { |s| s.key == "option.general.iframe_height" }.value
    end

    def set_livestream_phase_footer_tab_variables
      @all_livestreams = @projekt_phase.projekt_livestreams.order(created_at: :desc)
      @current_projekt_livestream = @all_livestreams.first
      @other_livestreams = @all_livestreams.select(:id, :title)
    end

    def set_formular_phase_footer_tab_variables
      auto_sign_in_guest_for(@projekt_phase)
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
      scope =
        if helpers.show_admin_controls_for_projekt?(@projekt)
          @projekt.projekt_phases
        else
          @projekt.projekt_phases.active.frontend_visible
        end

      default_phase_id ||= ProjektSetting.find_by(projekt: @projekt,
        key: "projekt_custom_feature.default_footer_tab")&.value

      @default_projekt_phase = scope.find_by(id: default_phase_id) || scope.first
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

    def can_view_stats_section?(section, phase)
      return true if current_user&.administrator? || current_user&.projekt_manager?

      case section
      when "key_metrics"
        phase.feature?("general.public_kpi_stats")
      when "analysis"
        phase.feature?("general.public_ai_stats")
      when "evaluation"
        helpers.footer_evaluation_tab_public_visible?(phase, "stats")
      when "ai_evaluation"
        helpers.footer_evaluation_tab_public_visible?(phase, "ai")
      else
        false
      end
    end
end
