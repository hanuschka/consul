class CreateAdminImagesAndMoveData < ActiveRecord::Migration[6.1]
  def up
    create_table :admin_images do |t|
      t.string :data_file_name, null: false
      t.string :data_content_type
      t.integer :data_file_size
      t.integer :width
      t.integer :height
      t.string :title, default: ""
      t.string :description, default: ""
      t.string :alt_text, default: ""
      t.tsvector :tsv, index: { using: :gin }
      t.bigint :projekt_id, index: true
      t.timestamps
    end

    AdminImage.reset_column_information

    move_admin_asset_images
    move_legacy_admin_flagged_images
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

    def move_admin_asset_images
      select_all("SELECT * FROM admin_assets WHERE type = 'AdminImage'").each do |row|
        image = AdminImage.new(
          data_file_name: row["data_file_name"],
          data_content_type: row["data_content_type"],
          data_file_size: row["data_file_size"],
          width: row["width"],
          height: row["height"],
          title: row["title"],
          description: row["description"],
          alt_text: row["alt_text"],
          projekt_id: row["projekt_id"],
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        )
        image.save!(validate: false)

        ActiveStorage::Attachment
          .where(record_type: "AdminAsset", record_id: row["id"], name: "storage_data")
          .update_all(record_type: "AdminImage", record_id: image.id)

        execute("DELETE FROM admin_assets WHERE id = #{row["id"].to_i}")
      end
    end

    def move_legacy_admin_flagged_images
      Image.unscoped.where(admin: true).find_each do |legacy_image|
        attachment = ActiveStorage::Attachment.find_by(
          record_type: "Image", record_id: legacy_image.id, name: "attachment"
        )
        next if attachment.nil?

        blob = attachment.blob
        next if blob.nil?

        metadata = blob.metadata || {}

        image = AdminImage.new(
          data_file_name: blob.filename.to_s,
          data_content_type: blob.content_type,
          data_file_size: blob.byte_size,
          width: metadata["width"],
          height: metadata["height"],
          title: legacy_image.title.presence || blob.filename.to_s,
          projekt_id: legacy_image.imageable_type == "Projekt" ? legacy_image.imageable_id : nil,
          created_at: legacy_image.created_at,
          updated_at: legacy_image.updated_at
        )
        image.save!(validate: false)

        attachment.update_columns(
          record_type: "AdminImage",
          record_id: image.id,
          name: "storage_data"
        )

        legacy_image.delete
      end
    end
end
