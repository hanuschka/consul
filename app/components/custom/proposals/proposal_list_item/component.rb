class Proposals::ProposalListItem::Component < ApplicationComponent
  attr_reader :proposal

  def initialize(proposal:, wide: false)
    @proposal = proposal
    @wide = wide
  end

  def component_attributes
    {
      resource: @proposal,
      title: proposal.title,
      description: proposal.summary,
      tags: proposal.tags.first(3),
      sdgs: proposal.related_sdgs.first(5),
      # start_date: proposal.total_duration_start,
      # end_date: proposal.total_duration_end,
      wide: @wide,
      resource_name: "Proposal",
      url: helpers.proposals_path(proposal),
      image_url: proposal.image&.variant(:medium),
      date: proposal.created_at,
      author: proposal.author,
      id: proposal.id
    }
  end
end
