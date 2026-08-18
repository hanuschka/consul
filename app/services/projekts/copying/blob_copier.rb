class Projekts::Copying::BlobCopier
  def initialize(id_map:)
    @id_map = id_map
  end

  # ActiveStorage::Attached::One#blank? is defined as !attached?, and it also
  # tolerates a nil argument, so it is the only guard needed.
  def copy_one(source_attached, copy_attached)
    return if source_attached.blank?

    copy_attached.attach(copy_blob(source_attached.blob))
  end

  # Attached::Many#attach re-assigns the whole association on each call, so the
  # blobs are collected first and attached in one go.
  def copy_many(source_attached, copy_attached)
    return if source_attached.blank?

    copy_blobs = source_attached.attachments.map { |attachment| copy_blob(attachment.blob) }
    return if copy_blobs.empty?

    copy_attached.attach(*copy_blobs)
  end

  private

    attr_reader :id_map

    # identify: false skips the Marcel content-type sniff -- the source blob
    # already carries an identified content type.
    def copy_blob(source_blob)
      copy_blob =
        source_blob.open do |file|
          ActiveStorage::Blob.create_and_upload!(
            io: file,
            filename: source_blob.filename,
            content_type: source_blob.content_type,
            metadata: source_blob.metadata,
            identify: false
          )
        end

      id_map.register_blob(source_blob, copy_blob)

      copy_blob
    end
end
