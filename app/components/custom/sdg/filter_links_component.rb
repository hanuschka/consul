require_dependency Rails.root.join("app", "components", "sdg", "filter_links_component").to_s

class SDG::FilterLinksComponent < ApplicationComponent
  delegate :link_list_sdg_goals, to: :helpers

  def index_by(advanced_search)
    if related_model.name == "Legislation::Proposal"
      legislation_process_proposals_path(params[:id], advanced_search: advanced_search, filter: params[:filter])
    elsif related_model.name == "Budget::Investment"
      investments_path
    else
      polymorphic_path(related_model, advanced_search: advanced_search)
    end
  end
end
