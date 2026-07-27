require_dependency Rails.root.join("app", "controllers", "polls_controller").to_s

class PollsController < ApplicationController

  include CommentableActions
  include ProjektControllerHelper
  include Takeable
  include GuestUsers
  include LandingPageResolvable

  before_action :set_geo_limitations, only: [:show, :results, :stats, :report, :evaluation, :ai_analysis]

  helper_method :resource_model, :resource_name
  has_filters %w[all current expired]

  def index
    resolve_landing_page_from_slug
    @resource_name = 'poll'
    @tag_cloud = tag_cloud

    @geozones = Geozone.all
    @districts = RegisteredAddress::District.all.sort_by(&:name_for_display)
    @selected_geozone_affiliation = params[:geozone_affiliation] || 'all_resources'
    @affiliated_districts = (params[:affiliated_districts] || '').split(',').map(&:to_i)
    @affiliated_geozones = (params[:affiliated_geozones] || '').split(',').map(&:to_i)
    @selected_geozone_restriction = params[:geozone_restriction] || 'no_restriction'
    @restricted_geozones = (params[:restricted_geozones] || '').split(',').map(&:to_i)

    @resources =
      Poll.with_phase_feature("resource.show_on_index_page")
        .created_by_admin
        .not_budget
        .send(@current_filter)
        .includes(:geozones)

    @resources = @resources.search(@search_terms) if @search_terms.present?

    related_projekt_ids = @resources.pluck("projekt_phases.projekt_id").uniq
    related_projekts = Projekt.where(id: related_projekt_ids)

    @scoped_projekt_ids = Projekt.visible_for(current_user).joins(voting_phases: :polls).select(:id)

    if @landing_page.present?
      lp_projekt_ids = landing_page_scoped_projekt_ids
      @scoped_projekt_ids = @scoped_projekt_ids.where(id: lp_projekt_ids)
    end

    @top_level_active_projekts = Projekt.top_level.current.where(id: @scoped_projekt_ids)
    @top_level_archived_projekts = Projekt.top_level.expired.where(id: @scoped_projekt_ids)

    @categories = Tag.category.joins(:taggings)
      .where(taggings: { taggable_type: "Projekt", taggable_id: related_projekt_ids }).order(:name).uniq

    if params[:sdg_goals].present?
      sdg_goal_ids = SDG::Goal.where(code: params[:sdg_goals].split(",")).ids
      @sdg_targets = SDG::Target.where(goal_id: sdg_goal_ids).joins(:relations)
        .where(sdg_relations: { relatable_type: "Projekt", relatable_id: related_projekt_ids })
    end

    @resources = @resources.by_projekt_id(@scoped_projekt_ids)
    @all_resources = @resources

    unless params[:search].present?
      take_by_tag_names(related_projekts)
      take_by_sdgs(related_projekts)
      take_by_geozone_affiliations
      take_by_polls_geozone_restrictions
      take_by_projekts(@scoped_projekt_ids)
    end

    @polls = Kaminari.paginate_array(@resources.sort_for_list).page(params[:page])

    respond_to do |format|
      format.html do
        if Setting.new_design_enabled?
          render :index_new
        else
          render :index
        end
      end
    end
  end

  def show
    auto_sign_in_guest_for(@poll.projekt_phase)

    @projekt_phase = @poll.projekt_phase

    answer_includes = [:translations, :images, :documents, :videos]

    @questions = @poll.questions.root_questions
                                .includes(:context, :poll, :translations, :votation_type, question_answers: answer_includes,
                                          nested_questions: [:poll, :votation_type, :translations, { question_answers: answer_includes }])
                                .order(given_order: :asc, id: :asc)
    @poll_questions_answers = Poll::Question::Answer.where(question: @poll.questions)

    @answers_by_question_id = {}

    @questions.each do |question|
      @answers_by_question_id[question.id] = []
    end

    poll_answers = ::Poll::Answer.by_question(@poll.question_ids).by_author(current_user&.id)
    poll_answers.each do |answer|
      @answers_by_question_id[answer.question_id] = @answers_by_question_id.has_key?(answer.question_id) ? @answers_by_question_id[answer.question_id].push(answer.answer) : [answer.answer]
    end

    @commentable = @poll
    @comment_tree = CommentTree.new(@commentable, params[:page], @current_order)

    resolve_landing_page_for_projekt(@projekt_phase&.projekt)

    if !@poll.projekt.visible_for?(current_user)
      @individual_group_value_names = @poll.projekt.individual_group_values.pluck(:name)
      render "custom/pages/forbidden", layout: false
    elsif Setting.new_design_enabled?
      render :show_new
    else
      render :show
    end
  end

  def stats
    @projekt_phase = @poll.projekt_phase
    @stats = Poll::Stats.new(@poll)

    if !@poll.projekt.visible_for?(current_user)
      @individual_group_value_names = @poll.projekt.individual_group_values.pluck(:name)
      render "custom/pages/forbidden", layout: false
    elsif Setting.new_design_enabled?
      render :stats_new
    else
      render :stats
    end
  end

  def results
    @projekt_phase = @poll.projekt_phase

    if !@poll.projekt.visible_for?(current_user)
      @individual_group_value_names = @poll.projekt.individual_group_values.pluck(:name)

      render "custom/pages/forbidden", layout: false
    elsif Setting.new_design_enabled?
      @results_phase =
        ProjektEvaluations::AggregateStatistics
          .new(@poll.projekt)
          .call_for_phase(@poll.projekt_phase)
          &.deep_stringify_keys

      @frontend_answer_poll = @poll

      render :results_new
    else
      render :results
    end
  end

  def report
    @projekt_phase = @poll.projekt_phase

    is_admin_or_manager = current_user&.administrator? || can?(:edit, @poll.projekt)
    can_view_report = is_admin_or_manager || (@poll.report_visible_for_citizens? && @poll.projekt.visible_for?(current_user))

    if !can_view_report
      @individual_group_value_names = @poll.projekt.individual_group_values.pluck(:name)
      render "pages/forbidden", layout: false
    end
  end

  def evaluation
    @projekt_phase = @poll.projekt_phase

    is_admin_or_manager = current_user&.administrator? || can?(:edit, @poll.projekt)
    can_view_evaluation = is_admin_or_manager || (@poll.evaluation_enabled? && @poll.projekt.visible_for?(current_user))

    if !can_view_evaluation
      @individual_group_value_names = @poll.projekt.individual_group_values.pluck(:name)
      render "pages/forbidden", layout: false
    end
  end

  def ai_analysis
    @projekt_phase = @poll.projekt_phase

    if !@poll.projekt.visible_for?(current_user)
      @individual_group_value_names = @poll.projekt.individual_group_values.pluck(:name)

      render "custom/pages/forbidden", layout: false
    end
  end

  def download_evaluation_section
    is_admin_or_manager = current_user&.administrator? || can?(:edit, @poll.projekt)
    return head(:forbidden) unless is_admin_or_manager

    content = @poll.ai_stats&.dig("evaluation")
    return head(:not_found) unless content.present?

    download_format = params[:format] || "txt"
    filename = "#{@poll.name.parameterize}-evaluation.#{download_format}"

    case download_format
    when "pdf"
      pdf = PdfServices::PollReportSectionExporter.new(
        @poll,
        { "title" => t("custom.polls.evaluation.title"), "content" => content }
      ).call
      send_data pdf.render,
                filename: filename,
                type: "application/pdf",
                disposition: "attachment"
    when "docx"
      docx = DocxServices::PollReportSectionExporter.new(
        @poll,
        { "title" => t("custom.polls.evaluation.title"), "content" => content }
      ).call
      send_data docx,
                filename: filename,
                type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                disposition: "attachment"
    else
      text = ActionView::Base.full_sanitizer.sanitize(content)
      send_data text,
                filename: filename,
                type: "text/plain",
                disposition: "attachment"
    end
  end

  def download_all_evaluation_sections
    is_admin_or_manager = current_user&.administrator? || can?(:edit, @poll.projekt)
    return head(:forbidden) unless is_admin_or_manager

    content = @poll.ai_stats&.dig("evaluation")
    return head(:not_found) unless content.present?

    download_format = params[:format] || "txt"
    filename = "#{@poll.name.parameterize}-evaluation-all.#{download_format}"

    case download_format
    when "pdf"
      pdf = PdfServices::PollReportSectionExporter.new(
        @poll,
        { "title" => t("custom.polls.evaluation.title"), "content" => content }
      ).call
      send_data pdf.render,
                filename: filename,
                type: "application/pdf",
                disposition: "attachment"
    when "docx"
      docx = DocxServices::PollReportSectionExporter.new(
        @poll,
        { "title" => t("custom.polls.evaluation.title"), "content" => content }
      ).call
      send_data docx,
                filename: filename,
                type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                disposition: "attachment"
    else
      text = ActionView::Base.full_sanitizer.sanitize(content)
      send_data text,
                filename: filename,
                type: "text/plain",
                disposition: "attachment"
    end
  end

  def refresh_ai_stats
    authorize!(:refresh_ai_stats, @poll)

    unless Ai::Settings.ai_available?
      respond_to do |format|
        format.html { redirect_back(fallback_location: report_poll_path(@poll)) }
        format.js { render json: { error: "AI features unavailable" }, status: :forbidden }
      end
      return
    end

    @poll.update(ai_stats_refresh_status: "pending")
    AiAnalytics::PollStatsRefresh.perform_later(@poll.id)

    respond_to do |format|
      format.html { redirect_to report_poll_path(@poll) }
      format.js { render json: { status_url: ai_stats_status_poll_path(@poll) } }
    end
  end

  def ai_stats_status
    authorize!(:ai_stats_status, @poll)

    response = { status: @poll.ai_stats_refresh_status || "pending" }

    if @poll.ai_stats_refresh_completed? && @poll.ai_stats_refreshed_at
      response[:last_updated_at] = l(@poll.ai_stats_refreshed_at, format: :short)
      response[:sections_html] = render_ai_stats_sections(params[:section])
    end

    render json: response
  end

  def download_report_section
    section_index = params[:section_index].to_i
    content = @poll.ai_stats&.dig("report")

    if content.is_a?(Hash) && content["reports"].present? && content["reports"][section_index].present?
      report = content["reports"][section_index]
      download_format = params[:format] || "txt"
      filename = generate_report_section_filename(@poll, section_index, download_format)

      case download_format
      when "pdf"
        pdf = PdfServices::PollReportSectionExporter.new(@poll, report).call
        send_data(
          pdf.render,
          filename: filename,
          type: "application/pdf",
          disposition: "attachment"
        )
      when "docx"
        docx = DocxServices::PollReportSectionExporter.new(@poll, report).call
        send_data(
          docx,
          filename: filename,
          type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
          disposition: "attachment"
        )
      else
        send_data(
          generate_report_section_text(report),
          filename: filename,
          type: "text/plain",
          disposition: "attachment"
        )
      end
    else
      head :not_found
    end
  end

  def download_all_report_sections
    content = @poll.ai_stats&.dig("report")

    if content.is_a?(Hash) && content["reports"].present?
      download_format = params[:format] || "txt"
      filename = generate_all_report_sections_filename(@poll, download_format)

      case download_format
      when "pdf"
        pdf = PdfServices::PollAllReportSectionsExporter.new(@poll, content["reports"]).call
        send_data(
          pdf.render,
          filename: filename,
          type: "application/pdf",
          disposition: "attachment"
        )
      when "docx"
        docx = DocxServices::PollAllReportSectionsExporter.new(@poll, content["reports"]).call
        send_data(
          docx,
          filename: filename,
          type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
          disposition: "attachment"
        )
      else
        send_data(
          generate_all_report_sections_text(content["reports"]),
          filename: filename,
          type: "text/plain",
          disposition: "attachment"
        )
      end
    else
      head :not_found
    end
  end

  def render_ai_stats_sections(section)
    section ||= "report"
    content = @poll.ai_stats&.dig(section)
    title = t("custom.polls.#{section}.title")

    if content.present?
      partial = section == "evaluation" ? "polls/ai_stats_evaluation_section" : "polls/ai_stats_report_sections"
      locals = { content: content, poll: @poll }
    else
      partial = "polls/ai_stats_empty_state"
      locals = { title: title }
    end

    render_to_string(partial: partial, locals: locals)
  end

  def set_geo_limitations
    @selected_geozone_affiliation = params[:geozone_affiliation] || 'all_resources'
    @affiliated_districts = (params[:affiliated_districts] || '').split(',').map(&:to_i)

    @selected_geozone_restriction = params[:geozone_restriction] || 'no_restriction'
    @restricted_geozones = (params[:restricted_geozones] || '').split(',').map(&:to_i)
  end

  def confirm_participation
    remove_answers_to_open_questions_with_blank_body
  end

  def csv_answers_votes
    authorize! :csv_answers_votes, @poll

    respond_to do |format|
      format.csv do
        send_data CsvServices::PollAnswersVotesExporter.new(@poll).call,
          filename: "poll_#{@poll.id}_answers_votes_#{Time.zone.today.strftime("%d/%m/%Y")}.csv"
      end
    end
  end

  private

    def generate_report_section_filename(poll, section_index, format)
      poll_name = poll.name.parameterize(separator: "-")
      "#{poll_name}-report-section-#{section_index + 1}.#{format}"
    end

    def generate_report_section_text(report)
      plain_content = helpers.strip_tags(report["content"].to_s)

      <<~TEXT
        #{report["title"]}

        #{plain_content}
      TEXT
    end

    def generate_all_report_sections_filename(poll, format)
      poll_name = poll.name.parameterize(separator: "-")
      "#{poll_name}-report-all.#{format}"
    end

    def generate_all_report_sections_text(reports)
      reports.map do |report|
        plain_content = helpers.strip_tags(report["content"].to_s)
        "#{report["title"]}\n\n#{plain_content}"
      end.join("\n\n#{'-' * 80}\n\n")
    end

    def remove_answers_to_open_questions_with_blank_body
      questions = @poll.questions.each do |question|
        open_question_answers_names = Poll::Question::Answer.where(question: question).select(&:open_answer).pluck(:title)
        open_answers_with_blank_text = Poll::Answer.where(question: question, author: current_user, answer: open_question_answers_names, open_answer_text: nil)
        open_answers_with_blank_text.destroy_all
      end
    end

    # def section(resource_name)
    #   "polls"
    # end

    def resource_model
      Poll
    end
end
