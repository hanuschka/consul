class WhatsappUserContributionsQuery < ApplicationQuery
  # What one citizen has published, newest first, as one list across both
  # resources. The bot flow submits a proposal or an investment depending on the
  # phase, so a citizen's own history spans the two without knowing it.
  def initialize(user:)
    @user = user
  end

  def call
    return [] if @user.blank?

    proposals = proposals_scope.includes(projekt_phase: { projekt: :page }).to_a
    investments = investments_scope.includes(budget: { projekt_phase: { projekt: :page }}).to_a

    (proposals + investments).sort_by(&:created_at).reverse
  end

  def exists?
    return false if @user.blank?

    proposals_scope.exists? || investments_scope.exists?
  end

  private

    def proposals_scope
      Proposal
        .where(author: @user)
        .order(created_at: :desc)
        .limit(::Whatsapp::MAX_LIST_ROWS)
    end

    def investments_scope
      Budget::Investment
        .where(author: @user)
        .order(created_at: :desc)
        .limit(::Whatsapp::MAX_LIST_ROWS)
    end
end
