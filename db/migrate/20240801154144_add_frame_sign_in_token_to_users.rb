class AddFrameSignInTokenToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :frame_sign_in_token, :string
    add_column :users, :frame_sign_in_token_valid_until, :datetime
  end
end
