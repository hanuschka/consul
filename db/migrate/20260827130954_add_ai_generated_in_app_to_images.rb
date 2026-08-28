class AddAiGeneratedInAppToImages < ActiveRecord::Migration[6.1]
  # Replaces the preserved copy of the generator's own bytes, which was a
  # full-size second attachment kept only so that its presence could answer
  # "did this app's generator produce the picture?". Nothing ever read those
  # bytes back, and the copy was never removed when the visible attachment was
  # replaced -- so an uploaded photograph inherited the answer, and with it the
  # exemption from stripping its camera EXIF.
  #
  # Separate from images.ai_generated, which is the public disclosure an admin
  # may set on a picture they made elsewhere and uploaded themselves.
  #
  # Backfilled from that copy alone: an image predating the marking feature
  # carries no marker for a strip to destroy, so FALSE is both accurate and the
  # safe default.
  def up
    add_column :images, :ai_generated_in_app, :boolean, default: false, null: false

    execute(<<~SQL.squish)
      UPDATE images
      SET ai_generated_in_app = TRUE
      WHERE id IN (
        SELECT record_id
        FROM active_storage_attachments
        WHERE record_type = 'Image'
          AND name = 'source_attachment'
      )
    SQL

    purge_source_attachments
  end

  def down
    remove_column :images, :ai_generated_in_app
  end

  private

    # Purged rather than only unlinked: the rows are what the flag was read
    # from, and leaving the blobs behind would keep paying storage for bytes no
    # code can reach any more.
    def purge_source_attachments
      ActiveStorage::Attachment
        .where(record_type: "Image", name: "source_attachment")
        .find_each(&:purge)
    end
end
