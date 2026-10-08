class AddProjektIdPositionIndexToSiteCustomizationContentBlocks < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index(
      :site_customization_content_blocks,
      [:projekt_id, :position],
      name: "index_scb_on_projekt_id_and_position",
      algorithm: :concurrently
    )
  end
end
