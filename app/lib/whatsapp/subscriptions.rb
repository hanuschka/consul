module Whatsapp::Subscriptions
  # Following a projekt from the chat writes the same ProjektSubscription row the
  # website's follow button writes, so following here and following there are one
  # state rather than two that disagree.
  #
  # Two named functions rather than one that flips: the citizen said which of the
  # two they wanted, and a toggle would make "follow X" twice unfollow them.
  # Rows are deactivated rather than destroyed, which is what the web side does
  # and what keeps an unfollow reversible.

  module_function

  def follow(user:, projekt:)
    write(user: user, projekt: projekt, active: true)
  end

  def unfollow(user:, projekt:)
    write(user: user, projekt: projekt, active: false)
  end

  def following?(user:, projekt:)
    ::ProjektSubscription.exists?(user: user, projekt: projekt, active: true)
  end

  def write(user:, projekt:, active:)
    ::ProjektSubscription
      .find_or_initialize_by(user: user, projekt: projekt)
      .update!(active: active)
  end

  private_class_method :write
end
