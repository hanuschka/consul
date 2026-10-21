class AddLastActivityIndexToWhatsappAccounts < ActiveRecord::Migration[6.1]
  def change
    # Serves both the /adm dialogs list order (COALESCE(last_inbound_at,
    # created_at) DESC) and the activity filter's range on last_inbound_at,
    # which otherwise sort the whole accounts table before Pagy takes 20 rows.
    add_index :whatsapp_accounts,
      "COALESCE(last_inbound_at, created_at) DESC",
      name: "index_whatsapp_accounts_on_last_activity"

    add_index :whatsapp_accounts, :last_inbound_at
  end
end
