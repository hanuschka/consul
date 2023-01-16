require_dependency Rails.root.join("app", "helpers", "tags_helper").to_s

module TagsHelper
  def taggables_path(taggable_type, tag_name)
    updated_params = prepare_tag_filter_params(tag_name)

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
      projekts_path(updated_params)
    else
      "#"
    end
  end

  def projekt_footer_filter_path(tag_name)
    updated_params = prepare_tag_filter_params(tag_name)

    if params[:current_tab_path]
      url_for(action: params[:current_tab_path], controller: "pages", **updated_params, format: :js)
    else
      url_for(action: "index", controller: controller_name, **updated_params, format: :js)
    end
  end

  def prepare_tag_filter_params(tag_name)
    currently_selected_tags = params[:tags].present? ? params[:tags].split(',') : []
    currently_selected_tags.include?(tag_name) ? currently_selected_tags.delete(tag_name) : currently_selected_tags.push(tag_name)
    selected_tags = currently_selected_tags.join(',')

    params.merge({tags: selected_tags}).permit(
      :tags, :geozone_affiliation, :geozone_restriction, :affiliated_geozones, :restricted_geozones,
      :sdg_goals, :sdg_targets,
      :order,
      filter_projekt_ids: []
    )
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
