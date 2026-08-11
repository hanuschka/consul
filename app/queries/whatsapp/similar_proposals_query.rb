class Whatsapp::SimilarProposalsQuery < ApplicationQuery
  # Proposals in this phase that may already be the idea a citizen is about to
  # write. base_selection is the portal's own definition of a publicly listed
  # proposal — published, not archived, not retired, admin-accepted — which is
  # also exactly the set that can be supported.
  #
  # Scoped to the one phase rather than portal-wide: the offer this feeds is
  # "support that one instead", and a proposal in a phase the citizen did not
  # choose is not the same participation.
  #
  # Wider than what is ever shown. The portal's index ranks on word overlap, so
  # it answers "same topic" — every playground proposal matches "Spielplatz
  # sanieren". The ranking step behind this one needs candidates to choose
  # from, and decides which of them are the same request.
  CANDIDATE_LIMIT = 10

  def initialize(projekt_phase:, text:)
    @projekt_phase = projekt_phase
    @text = text.to_s.strip
  end

  def call
    return [] if @projekt_phase.blank?
    return [] if @text.blank?

    # Not `search`, which is the search box's question and ANDs every token of
    # it. What is matched here was never typed into a box: it is the citizen's
    # whole idea, and no proposal contains all fifteen words of a paragraph. The
    # strict scope would answer nothing at all, every time, silently.
    Proposal
      .base_selection
      .where(projekt_phase_id: @projekt_phase.id)
      .pg_search_any_word(@text)
      .limit(CANDIDATE_LIMIT)
      .to_a
  end
end
