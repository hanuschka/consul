# Blobs are named by id in the bundle, so duplicating one is a lookup away.
# There is no second, inert implementation of this: an export drops the media
# keys altogether, so on that path every method here is handed nothing.
class Projekts::Copying::BlobCopier
  def initialize(id_map:)
    @id_map = id_map
  end

  def copy_one(blob_id, copy_attached)
    return if blob_id.blank?

    source_blob = ActiveStorage::Blob.find_by(id: blob_id)
    return if source_blob.blank?

    copy_attached.attach(copy_blob(source_blob))
  end

  # Attached::Many#attach re-assigns the whole association on each call, so the
  # blobs are collected first and attached in one go. They are looked up one by
  # one to keep the bundle's order.
  def copy_many(blob_ids, copy_attached)
    source_blobs = Array(blob_ids).filter_map { |id| ActiveStorage::Blob.find_by(id: id) }
    return if source_blobs.empty?

    copy_attached.attach(*source_blobs.map { |source_blob| copy_blob(source_blob) })
  end

  # Image and Document are the app's polymorphic attachment wrappers. Both
  # validate the attachment for presence, so the blob has to be attached to the
  # copy before it is saved.
  def copy_attachables(model, owner_key, nodes, copy, record_copier:)
    Array(nodes).each do |node|
      record_copy = record_copier.build(node, attributes: { owner_key => copy })
      copy_one(node.dig("attachments", "attachment"), record_copy.attachment)
      record_copier.persist(node, record_copy)
    end
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
