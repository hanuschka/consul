# Supporting a match instead of publishing is offered on two surfaces -- the
# modal the check opens, and the decision block the citizen comes back to on
# the form -- so the vote markup, the link to a supported match and the id
# tying the two together are built the same way for both. The prefix keeps the
# two surfaces' ids apart while both are in the document.
module SimilarContributionsSupporting
  extend ActiveSupport::Concern

  def votes_container_id(match_resource)
    "#{votes_container_prefix}_#{dom_id(match_resource)}_votes"
  end

  def path_for(match_resource)
    helpers.similar_contributions_path_for(match_resource)
  end

  def supporting_available?(match_resource)
    projekt_phase = match_resource.projekt_phase

    return false if projekt_phase.blank?

    projekt_phase_feature?(projekt_phase, "resource.allow_voting")
  end

  def votes_component_for(match_resource)
    if match_resource.is_a?(::Budget::Investment)
      ::Budgets::Investments::VotesComponent.new(match_resource)
    else
      ::Proposals::NewVotesComponent.new(
        match_resource,
        vote_url: vote_proposal_path(match_resource, value: "yes")
      )
    end
  end
end
