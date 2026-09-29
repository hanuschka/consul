class AddAiDisclosedAtToWhatsappAccounts < ActiveRecord::Migration[6.1]
  # The disclosure is now shown once per number rather than once per 24-hour
  # window, and no existing column answers "has this number been told". Account
  # #greeted? is already true for every number a broadcast ever reached, and the
  # conversation's last_inbound_at only dates the window.
  #
  # Backfilled so a number that has already heard it does not hear it again.
  # The condition is a reply, not merely an outbound message: every account the
  # bot has answered went through the first-contact or per-session disclosure,
  # whereas an account that only ever received a broadcast has heard nothing and
  # must still be told on its first message.
  def up
    add_column :whatsapp_accounts, :ai_disclosed_at, :datetime

    execute(<<~SQL)
      UPDATE whatsapp_accounts
      SET ai_disclosed_at = replies.first_reply_at
      FROM (
        SELECT whatsapp_account_id, MIN(created_at) AS first_reply_at
        FROM whatsapp_messages
        WHERE direction = 'outbound' AND kind <> 'template'
        GROUP BY whatsapp_account_id
      ) AS replies
      WHERE whatsapp_accounts.id = replies.whatsapp_account_id
    SQL
  end

  def down
    remove_column :whatsapp_accounts, :ai_disclosed_at
  end
end
