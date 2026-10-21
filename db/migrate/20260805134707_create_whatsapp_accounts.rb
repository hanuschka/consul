class CreateWhatsappAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :whatsapp_accounts do |t|
      t.string :wa_id, null: false
      t.string :phone
      t.string :profile_name
      t.integer :user_id
      t.string :state, null: false, default: "unlinked"
      t.datetime :verified_at
      t.datetime :opt_in_at
      t.datetime :opt_out_at
      t.datetime :last_inbound_at
      t.string :link_token
      t.datetime :link_token_sent_at

      t.timestamps
    end

    add_index :whatsapp_accounts, :wa_id, unique: true
    add_index :whatsapp_accounts, :link_token, unique: true
    add_index :whatsapp_accounts, :user_id
    add_index :whatsapp_accounts, [:verified_at, :opt_out_at]
  end
end
