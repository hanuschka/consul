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

  scope :linked_to_user, -> { joins(:user).where(users: { erased_at: nil }) }
  scope :verified, -> { where.not(verified_at: nil) }
  scope :subscribed, -> { verified.linked_to_user.where(opt_out_at: nil).where.not(opt_in_at: nil) }

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
