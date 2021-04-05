module SearchHelper
  def official_level_search_options
    options_for_select((1..5).map { |i| [setting["official_level_#{i}_name"], i] },
                       params[:advanced_search].try(:[], :official_level))
  end

  def date_range_options
    options_for_select([
      [t("shared.advanced_search.date_1"), 1],
      [t("shared.advanced_search.date_2"), 2],
      [t("shared.advanced_search.date_3"), 3],
      [t("shared.advanced_search.date_4"), 4],
      [t("shared.advanced_search.date_5"), "custom"]],
      selected_date_range)
  end

  def selected_date_range
    custom_date_range? ? "custom" : params[:advanced_search].try(:[], :date_min)
  end

  def custom_date_range?
    params[:advanced_search].try(:[], :date_max).present?
  end

  def sanitize_search(html)
    ActionController::Base.helpers.sanitize(html, tags: ["em"], attributes: ["class"])
  end


  def search_result_link(result)
          tp = %w[Debate Proposal Budget::Investment Poll Topic
                        Legislation::Question Legislation::Annotation
                        Legislation::Proposal].freeze
    case result.model_name
    when"comment"
      case result.commentable_type

      when "Debate"
        debate_path(result.commentable_id, anchor: "comment_#{result.id}")
      when "Proposal"
        proposal_path(result.commentable_id, anchor: "comment_#{result.id}")
      when "Budget::Investment"
        budget_investment_path(result.budget_id, result.commentable_id, anchor: "comment_#{result.id}")
      when "Poll"
        poll_path(result.commentable_id, anchor: "comment_#{result.id}")
      when 'Topic'
        community_topic_path(result.community_id, result.commentable_id, anchor: "comment_#{result.id}")
      else
        result.commentable_type
      end
    when 'debate'
      debate_path(result.id)
    when 'budget_investment'
      budget_investment_path(result.budget_id, result.id)
    when 'proposal'
      proposal_path(result.id)
    when 'legislation_proposal'
      legislation_process_proposal_path(result.process_id, result.id)
    when 'poll'
      poll_path(result.id)
    when 'site_customization_page'
      page_path(result.slug)


    else
      debate_path(result.id)
    end
  end
end