class Whatsapp::Account < ApplicationRecord
  LINK_TOKEN_TTL = 1.hour

  STATE_BADGE_VARIANTS = {
    "linked" => "success",
    "link_pending" => "warning",
    "unlinked" => "info"
  }.freeze

  belongs_to :user, optional: true

  # Both sides keep their original column and association names, so the class
  # and the foreign key have to be spelled out: Rails would otherwise infer
  # Whatsapp::WhatsappConversation and account_id.
  has_one :whatsapp_conversation,
    class_name: "Whatsapp::Conversation",
    foreign_key: :whatsapp_account_id,
    inverse_of: :whatsapp_account,
    dependent: :destroy

  has_many :whatsapp_messages,
    class_name: "Whatsapp::Message",
    foreign_key: :whatsapp_account_id,
    inverse_of: :whatsapp_account,
    dependent: :destroy

  enum state: {
    unlinked: "unlinked",
    link_pending: "link_pending",
    linked: "linked"
  }

  validates :wa_id, presence: true, uniqueness: true

  # Ordered: this is the order the catalog's settings list prints them in, and
  # the order is spent top down against WhatsApp's ten-row budget.
  NOTIFICATION_TYPES = %i[
    new_projekt
    deadline_approaching
    deadline_passed
    new_supports
    new_comments
    moderation_decision
  ].freeze

  NOTIFICATION_COLUMNS =
    NOTIFICATION_TYPES.index_with { |type| :"notify_#{type}" }.freeze

  scope :linked_to_user, -> { joins(:user).where(users: { erased_at: nil }) }
  scope :verified, -> { where.not(verified_at: nil) }
  scope :subscribed, -> { verified.linked_to_user.where(opt_out_at: nil).where.not(opt_in_at: nil) }

  # Composed onto `subscribed` by every push, so opting out of the channel and
  # switching off one notification type are answered by one query rather than by
  # each job remembering to ask both questions.
  scope :subscribed_to, ->(type) { subscribed.where(NOTIFICATION_COLUMNS.fetch(type) => true) }

  def subscribed?
    verified_at.present? && user_id.present? && opt_in_at.present? && opt_out_at.nil?
  end

  # Opting back in has to clear opt_out_at as well as stamp opt_in_at, which is
  # the pair `subscribed` reads. Written here so the bot keyword, the recovery
  # button, the assistant and the account page cannot each write half of it.
  def opt_in!
    update!(opt_in_at: Time.current, opt_out_at: nil)
  end

  def opt_out!
    update!(opt_out_at: Time.current)
  end

  # Whether this number has ever been written to. What separates a genuine
  # first contact — which gets the catalog's three opening messages — from
  # someone writing in again after a quiet week, who gets only the AI
  # disclosure. Asked of the messages rather than of a flag on the conversation
  # because resetting a flow clears the conversation's context.
  def greeted?
    Whatsapp::Message.exists?(whatsapp_account_id: id, direction: "outbound")
  end

  def notifies?(type)
    self[NOTIFICATION_COLUMNS.fetch(type)]
  end

  def toggle_notification!(type)
    column = NOTIFICATION_COLUMNS.fetch(type)

    update!(column => !self[column])
  end

  # Unlinking is self-service, so it clears everything that ties the number to a
  # citizen in one write: the account row stays (it is the conversation's
  # parent) but carries nothing about who was behind it.
  def unlink!
    update!(
      user_id: nil,
      state: "unlinked",
      verified_at: nil,
      link_token: nil,
      link_token_sent_at: nil
    )
  end

  def state_badge_variant
    STATE_BADGE_VARIANTS.fetch(state, "info")
  end

  def contact_label
    profile_name.presence || phone.presence || wa_id
  end

  def link_token_valid?
    link_token.present? && link_token_sent_at.present? &&
      link_token_sent_at > LINK_TOKEN_TTL.ago
  end

  # Two messages from the same number are two jobs, and each asks for the
  # conversation before the advisory lock can be taken — the lock needs this id
  # to exist. So the unique index is the arbiter: the loser of the race reads
  # the row the winner just wrote instead of failing its job.
  def conversation
    whatsapp_conversation || create_whatsapp_conversation!
  rescue ActiveRecord::RecordNotUnique
    reload.whatsapp_conversation
  end
end
