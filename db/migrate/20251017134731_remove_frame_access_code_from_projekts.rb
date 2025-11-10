class RemoveFrameAccessCodeFromProjekts < ActiveRecord::Migration[6.1]
  def change
    remove_column :projekts, :frame_access_code
  end
end
