class WhatsappFollowedProjektsQuery < ApplicationQuery
  # The same ProjektSubscription rows the website's follow button writes, so a
  # projekt followed on the web is followed in the chat and unfollowing in
  # either place is the same act.
  def initialize(user:)
    @user = user
  end

  def call
    return [] if @user.blank?

    Projekt
      .joins(:subscriptions)
      .where(projekt_subscriptions: { user_id: @user.id, active: true })
      .includes(:page)
      .order("projekts.created_at DESC")
      .limit(::Whatsapp::MAX_LIST_ROWS)
      .to_a
  end
end
