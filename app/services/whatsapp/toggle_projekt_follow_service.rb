class Whatsapp::ToggleProjektFollowService < ApplicationService
  # Writes the same ProjektSubscription row the website's follow button writes,
  # so following in the chat and following on the site are one state rather than
  # two that disagree. Rows are deactivated rather than destroyed, which is what
  # the web side does and what keeps an unfollow reversible.
  #
  # Returns :followed or :unfollowed. Kept for the archived menu, which asks for
  # a flip rather than for a state.
  def initialize(user:, projekt:)
    @user = user
    @projekt = projekt
  end

  def call
    subscription = ProjektSubscription.find_or_initialize_by(user: @user, projekt: @projekt)

    subscription.update!(active: !subscription.active?)

    subscription.active? ? :followed : :unfollowed
  end

  # The catalog's "Subscribe X" / "Unsubscribe X" name the state they want
  # rather than asking for it to be flipped, so repeating the command is a
  # no-op instead of undoing what it just did.
  def self.follow(user:, projekt:)
    write(user: user, projekt: projekt, active: true)

    :followed
  end

  def self.unfollow(user:, projekt:)
    write(user: user, projekt: projekt, active: false)

    :unfollowed
  end

  def self.write(user:, projekt:, active:)
    ProjektSubscription
      .find_or_initialize_by(user: user, projekt: projekt)
      .update!(active: active)
  end
  private_class_method :write

  def self.following?(user:, projekt:)
    return false if user.blank?

    ProjektSubscription.exists?(user_id: user.id, projekt_id: projekt.id, active: true)
  end
end
