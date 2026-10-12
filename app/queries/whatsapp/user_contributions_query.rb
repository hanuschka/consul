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

  # Over the whole history rather than the page, for the same reason as #total:
  # "welche davon werden noch geprüft?" read off one page was answered as "none of
  # the ten shown" about a citizen with fifty. Only a proposal waits for review —
  # an investment is public the moment it is sent (MyContributions#public?).
  def counts
    return { total: 0, public: 0, under_review: 0 } if @user.blank?

    all_count = total
    under_review_count = proposals_scope.where(admin_accepted: false).count

    {
      total: all_count,
      public: all_count - under_review_count,
      under_review: under_review_count
    }
  end

  def exists?
    return false if @user.blank?

    proposals_scope.exists? || investments_scope.exists?
  end

  private

    def through_window(scope)
      scope.limit(::Whatsapp::ListWindow.limit_through(@from))
    end

    # Published ones only: a draft never sent in is not a contribution yet, and
    # the row it made was opened with the line that it is being reviewed.
    def proposals_scope
      Proposal
        .published
        .where(author: @user)
        .order(created_at: :desc)
    end

    def investments_scope
      Budget::Investment
        .where(author: @user)
        .order(created_at: :desc)
    end
end
