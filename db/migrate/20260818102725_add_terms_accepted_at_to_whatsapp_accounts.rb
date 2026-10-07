class AddTermsAcceptedAtToWhatsappAccounts < ActiveRecord::Migration[6.1]
  def change
    add_column :whatsapp_accounts, :terms_accepted_at, :datetime
  end
end
