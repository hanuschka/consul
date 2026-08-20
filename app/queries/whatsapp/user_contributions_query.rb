class Whatsapp::UserContributionsQuery < ApplicationQuery
  # What one citizen has published, newest first, as one list across both
  # resources. The bot flow submits a proposal or an investment depending on the
  # phase, so a citizen's own history spans the two without knowing it.
  def initialize(user:, from: 0)
    @user = user
    @from = from
  end

  # Both resources are loaded up to the end of the window and the page taken after
  # the merge, because which resource a row belongs to is not known until the two
  # are sorted together: offsetting either scope in SQL would skip rows the merge
  # had not placed yet.
  def call
    return [] if @user.blank?

    proposals = through_window(proposals_scope).includes(projekt_phase: { projekt: :page }).to_a
    investments = through_window(investments_scope)
      .includes(budget: { projekt_phase: { projekt: :page }})
      .to_a

    ::Whatsapp::ListWindow.page(
      (proposals + investments).sort_by(&:created_at).reverse, from: @from
    )
  end

  # Counted rather than measured off the rows: the window cannot say how much it
  # cut, and a citizen's own history is the list they most expect to be complete.
  def total
    return 0 if @user.blank?

    proposals_scope.count + investments_scope.count
  end

  def exists?
    return false if @user.blank?

    proposals_scope.exists? || investments_scope.exists?
  end

  private

    def through_window(scope)
      scope.limit(::Whatsapp::ListWindow.limit_through(@from))
    end

    def proposals_scope
      Proposal
        .where(author: @user)
        .order(created_at: :desc)
    end

    def investments_scope
      Budget::Investment
        .where(author: @user)
        .order(created_at: :desc)
    end
end
