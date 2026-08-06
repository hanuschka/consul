class WhatsappUserContributionsQuery < ApplicationQuery
  MAX_PER_RESOURCE = 10

  # What one citizen has published, newest first, as one list across both
  # resources. The bot flow submits a proposal or an investment depending on the
  # phase, so a citizen's own history spans the two without knowing it.
  def initialize(user:)
    @user = user
  end

  def call
    return [] if @user.blank?

    (proposals + investments).sort_by(&:created_at).reverse
  end

  private

    def proposals
      Proposal
        .where(author: @user)
        .includes(projekt_phase: { projekt: :page })
        .order(created_at: :desc)
        .limit(MAX_PER_RESOURCE)
        .to_a
    end

    def investments
      Budget::Investment
        .where(author: @user)
        .includes(budget: { projekt_phase: { projekt: :page }})
        .order(created_at: :desc)
        .limit(MAX_PER_RESOURCE)
        .to_a
    end
end
