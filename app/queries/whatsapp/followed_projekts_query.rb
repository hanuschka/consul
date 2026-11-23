class Whatsapp::FollowedProjektsQuery < ApplicationQuery
  # The same ProjektSubscription rows the website's follow button writes, so a
  # projekt followed on the web is followed in the chat and unfollowing in
  # either place is the same act.
  def initialize(user:, from: 0)
    @user = user
    @from = from
  end

  # Everything the citizen follows, for resolving a name rather than showing a
  # list. Unfollowing the eleventh projekt on that list names one the display
  # cut, and a name that resolves to nothing is answered "no such projekt" —
  # which reads as the portal having lost it, while the messages keep coming.
  def self.uncapped(user:)
    new(user: user).uncapped
  end

  # Capped in SQL, not in Ruby: pages carry translated content, so loading a
  # citizen's sixtieth followed projekt to render ten is sixty fat rows for
  # fifty that are thrown away.
  def call
    return [] if @user.blank?

    listed_scope
      .offset(::Whatsapp::ListWindow.offset(@from))
      .limit(::Whatsapp::ListWindow::ROWS)
      .to_a
  end

  def total
    return 0 if @user.blank?

    listed_scope.count
  end

  def uncapped
    return [] if @user.blank?

    scope.to_a
  end

  private

    # The list shows only what an anonymous visitor can see. Unfollowing still
    # resolves against every followed projekt, so one restricted after it was
    # followed never traps its followers in the subscriber newsletters.
    def listed_scope
      scope.visible_for(nil)
    end

    # The title every match is decided on is Globalize-translated, so the
    # translations are preloaded with the page — without them each candidate
    # costs its own page_translations SELECT, which name resolution pays per
    # row.
    def scope
      Projekt
        .joins(:subscriptions)
        .where(projekt_subscriptions: { user_id: @user.id, active: true })
        .includes(page: :translations)
        .order("projekts.created_at DESC")
    end
end
