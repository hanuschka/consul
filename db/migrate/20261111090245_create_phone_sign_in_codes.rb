class CreatePhoneSignInCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :phone_sign_in_codes do |t|
      t.string :phone_digest, null: false
      t.string :code_digest, null: false
      t.string :ip_digest
      t.integer :attempts, default: 0, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end

    add_index :phone_sign_in_codes, [:phone_digest, :created_at]
    add_index :phone_sign_in_codes, [:ip_digest, :created_at]
    add_index :phone_sign_in_codes, :created_at
  end
end
