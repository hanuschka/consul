class Whatsapp::NotificationDelivery < ApplicationRecord
  # The receipt for a time-triggered push. Written before the send rather than
  # after it: a crash between the two costs one missed reminder, whereas the
  # other order costs a duplicate every time the daily job is retried.
  belongs_to :whatsapp_account, class_name: "Whatsapp::Account"
  belongs_to :projekt_phase, class_name: "::ProjektPhase", optional: true

  KINDS = %w[deadline_approaching deadline_passed].freeze

  validates :kind, inclusion: { in: KINDS }

  # Returns false when this account has already been told, so the caller can
  # skip the send without asking a second question.
  #
  # insert_all rather than create! with a rescue: the unique index is the
  # arbiter either way, but a raised RecordNotUnique aborts the surrounding
  # PostgreSQL transaction, and everything after it in the same transaction then
  # fails too. ON CONFLICT DO NOTHING answers the same question without ever
  # putting the connection in that state.
  def self.claim(account_id:, projekt_phase_id:, kind:)
    now = Time.current

    inserted = insert_all(
      [{
        whatsapp_account_id: account_id,
        projekt_phase_id: projekt_phase_id,
        kind: kind,
        sent_at: now,
        created_at: now,
        updated_at: now
      }],
      returning: :id
    )

    inserted.any?
  end
end
