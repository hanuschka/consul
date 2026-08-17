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

  def copy_many(source_attached, copy_attached)
    return if source_attached.blank?

    source_attached.attachments.each do |attachment|
      copy_attached.attach(copy_blob(attachment.blob))
    end
  end

  private

    attr_reader :id_map

    def copy_blob(source_blob)
      copy_blob =
        source_blob.open do |file|
          ActiveStorage::Blob.create_and_upload!(
            io: file,
            filename: source_blob.filename,
            content_type: source_blob.content_type,
            metadata: source_blob.metadata
          )
        end

      id_map.register_blob(source_blob, copy_blob)

      copy_blob
    end
end
