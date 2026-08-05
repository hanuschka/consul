class WhatsappAccount < ApplicationRecord
  LINK_TOKEN_TTL = 1.hour

  belongs_to :user, optional: true
  has_one :whatsapp_conversation, dependent: :destroy
  has_many :whatsapp_messages, dependent: :destroy

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

  def link_token_valid?
    link_token.present? && link_token_sent_at.present? &&
      link_token_sent_at > LINK_TOKEN_TTL.ago
  end

  def conversation
    whatsapp_conversation || create_whatsapp_conversation!
  end
end
