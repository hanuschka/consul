class Whatsapp::FollowedProjektsQuery < ApplicationQuery
  # The same ProjektSubscription rows the website's follow button writes, so a
  # projekt followed on the web is followed in the chat and unfollowing in
  # either place is the same act.
  def initialize(user:)
    @user = user
  end

  # Everything the citizen follows, for resolving a name rather than showing a
  # list. Unfollowing the eleventh projekt on that list names one the display
  # cut, and a name that resolves to nothing is answered "no such projekt" —
  # which reads as the portal having lost it, while the messages keep coming.
  def self.uncapped(user:)
    new(user: user).uncapped
  end

  def call
    uncapped.first(::Whatsapp::MAX_LIST_ROWS)
  end

  def uncapped
    return [] if @user.blank?

    Projekt
      .joins(:subscriptions)
      .where(projekt_subscriptions: { user_id: @user.id, active: true })
      .includes(:page)
      .order("projekts.created_at DESC")
      .to_a
  end
end
