require_dependency Rails.root.join("app", "helpers", "tags_helper").to_s

module TagsHelper
  def taggables_path(taggable_type, tag_name)
    selected_tags = ::Tags::ToggleSelectionService.call(params[:tags], tag_name)

    updated_params = params.merge({tags: selected_tags}).permit(
      :tags, :geozone_affiliation, :geozone_restriction, :affiliated_districts, :restricted_geozones,
      :sdg_goals, :sdg_targets,
      :order,
      filter_projekt_ids: []
    )

    case taggable_type
    when "debate"
      debates_path(updated_params)
    when "proposal"
      proposals_path(updated_params)
    when "poll"
      polls_path(updated_params)
    when "budget/investment"
      budget_investments_path(@budget, updated_params)
    when "legislation/proposal"
      legislation_process_proposals_path(@process, updated_params)
    when "projekt"
      if params[:landing_page_slug].present?
        landing_page_projekts_path(params[:landing_page_slug], updated_params)
      else
        projekts_path(updated_params)
      end
    else
      "#"
    end
  end

  def taggable_path(taggable)
    taggable_type = taggable.class.name.underscore
    case taggable_type
    when "debate"
      debate_path(taggable)
    when "proposal"
      proposal_path(taggable)
    when "poll"
      poll_path(taggable)
    when "budget/investment"
      budget_investment_path(taggable.budget_id, taggable)
    when "legislation/proposal"
      legislation_process_proposal_path(@process, taggable)
    else
      "#"
    end
  end
end
