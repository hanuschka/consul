class Whatsapp::SupportableProposalsQuery < ApplicationQuery
  # Proposals a citizen could plausibly mean when they say they want to support
  # "the one about the playground". base_selection is the portal's own
  # definition of a publicly listed proposal — published, not archived, not
  # retired, admin-accepted — which is exactly the set that may be supported
  # from outside the projekt page.
  #
  # Deliberately few results: this feeds a chat reply, and a citizen scanning
  # eight near-identical titles on a phone will pick the wrong one.
  MAX_RESULTS = 3

  def initialize(text:)
    @text = text.to_s.strip
  end

  def call
    return [] if @text.blank?

    Proposal
      .base_selection
      .where("proposals.title ILIKE ?", "%#{sanitized_text}%")
      .includes(projekt_phase: { projekt: :page })
      .order(cached_votes_up: :desc)
      .limit(MAX_RESULTS)
      .to_a
  end

  private

    def sanitized_text
      ActiveRecord::Base.sanitize_sql_like(@text)
    end
end
