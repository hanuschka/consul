module Whatsapp::ContributionFacts
  # What the assistant is told about one contribution, wherever it comes to hear of
  # one: found by find_contribution from what the citizen called it, or tapped on a
  # row of a list. One set of facts for both, because a contribution the citizen
  # opened by tapping and one they asked about by name are the same contribution,
  # and the reply to one used to be a bare link while the other came with its
  # supports and a way to support it.
  #
  # Reads the same things off a proposal and off a budget investment:
  # Budget::Investment delegates projekt_phase to its budget, so neither the
  # class nor the shape has to be branched on here.
  module_function

  def call(contribution, user:)
    projekt = contribution.projekt_phase&.projekt

    {
      contribution_id: contribution.id,
      title: contribution.title,
      projekt: projekt.present? ? ::Whatsapp::ProjektLink.title(projekt) : nil,
      written_by_you: written_by?(contribution, user),
      supports: contribution.cached_votes_up,
      supported_by_you: supported_by?(contribution, user),
      supportable: contribution.is_a?(::Proposal),
      support_action_id: support_action_id(contribution)
    }.compact
  end

  # Absent for an unlinked number, which has written nothing the portal knows of.
  def written_by?(contribution, user)
    return if user.blank?

    contribution.author_id == user.id
  end

  # Read the way the pill beside the sentence reads it, through
  # Whatsapp::AssistantActions#support_action, so the two cannot come
  # apart: a support registered in an earlier session is not in the transcript,
  # and with no fact to write from the model offers a support the button under
  # it is already labelled "withdraw".
  #
  # Absent rather than false for a budget investment and for an unlinked number.
  # Neither is a proposal this citizen has not supported yet, and reported as
  # false both would read as one.
  def supported_by?(contribution, user)
    return if !contribution.is_a?(::Proposal) || user.blank?

    contribution.voted_up_by?(user)
  end

  # Handed over rather than left for the model to compose, the way draft_proposal
  # hands over its candidates'. Which way the pill goes is read off the vote when
  # it is sent, and a proposal that can no longer be supported loses the pill there.
  #
  # Supporting a budget investment is budget voting rather than a support click, so
  # only proposals report as supportable.
  def support_action_id(contribution)
    return if !contribution.is_a?(::Proposal)

    "support_toggle-#{contribution.id}"
  end
end
