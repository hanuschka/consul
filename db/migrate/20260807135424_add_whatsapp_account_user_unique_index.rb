class AddWhatsappAccountUserUniqueIndex < ActiveRecord::Migration[6.1]
  # One number per account, enforced where the application check could not:
  # Whatsapp::Accounts::ConfirmLinkService reads before it writes, so two confirmations
  # racing on the same user both passed. Postgres treats NULLs as distinct, so
  # unlinked rows are unaffected.
  def change
    remove_index :whatsapp_accounts, :user_id
    add_index :whatsapp_accounts, :user_id, unique: true
  end
end
