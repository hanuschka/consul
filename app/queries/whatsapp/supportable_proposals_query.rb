class Whatsapp::SupportableProposalsQuery < ApplicationQuery
  # Proposals a citizen could plausibly mean when they say they want to support
  # "the one about the playground". base_selection is the portal's own
  # definition of a publicly listed proposal — published, not archived, not
  # retired, admin-accepted — which is exactly the set that may be supported
  # from outside the projekt page.
  #
  # Searched through the portal's own index rather than by matching the title
  # column: there is no title column to match (Proposal translates it), and the
  # citizen is describing a proposal in their own words, which is the case
  # Searchable's stemming and ranking exist to handle. It already orders by
  # supports within rank, so no ordering is added here.
  #
  # Deliberately few results: this feeds a chat reply, and a citizen scanning
  # eight near-identical titles on a phone will pick the wrong one.
  MAX_RESULTS = 3

  def initialize(text:)
    @text = text.to_s.strip
  end

  def call
    return [] if @text.blank?

    Proposal.base_selection.search(@text).limit(MAX_RESULTS).to_a
  end
end
