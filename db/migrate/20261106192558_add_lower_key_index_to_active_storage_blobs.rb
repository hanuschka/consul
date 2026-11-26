class AddLowerKeyIndexToActiveStorageBlobs < ActiveRecord::Migration[7.2]
  def change
    add_index :active_storage_blobs, "LOWER(key)", name: "index_active_storage_blobs_on_lower_key"
  end
end
