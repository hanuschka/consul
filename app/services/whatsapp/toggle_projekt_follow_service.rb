class Whatsapp::ToggleProjektFollowService < ApplicationService
  # Writes the same ProjektSubscription row the website's follow button writes,
  # so following in the chat and following on the site are one state rather than
  # two that disagree. Rows are deactivated rather than destroyed, which is what
  # the web side does and what keeps an unfollow reversible.
  #
  # Returns :followed or :unfollowed.
  def initialize(user:, projekt:)
    @user = user
    @projekt = projekt
  end

  def call
    subscription = ProjektSubscription.find_or_initialize_by(user: @user, projekt: @projekt)

    subscription.update!(active: !subscription.active?)

    subscription.active? ? :followed : :unfollowed
  end

  def self.following?(user:, projekt:)
    return false if user.blank?

    ProjektSubscription.exists?(user_id: user.id, projekt_id: projekt.id, active: true)
  end
end
