class RemoveFrameSignInTokenFromUsers < ActiveRecord::Migration[6.1]
  def change
    remove_column :users, :frame_sign_in_token, :string
    remove_column :users, :frame_sign_in_token_valid_until, :datetime
  end
end
