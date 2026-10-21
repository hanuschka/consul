# Blobs are named by id in the bundle, so duplicating one is a lookup away.
# There is no second, inert implementation of this: an export drops the media
# keys altogether, so on that path every method here is handed nothing.
class Projekts::Copying::BlobCopier
  def initialize(id_map:)
    @id_map = id_map
    @skipped_blobs = []
  end

  # What the copy could not carry over, for the job to persist. A source blob
  # whose file is gone is a defect in the source, not a reason to lose the whole
  # copy -- so it is collected here and the traversal continues.
  attr_reader :skipped_blobs

  def copy_one(blob_id, copy_attached)
    return if blob_id.blank?

    source_blob = ActiveStorage::Blob.find_by(id: blob_id)
    return if source_blob.blank?

    copy = copy_blob(source_blob)
    return if copy.blank?

    copy_attached.attach(copy)
  end

  # Attached::Many#attach re-assigns the whole association on each call, so the
  # blobs are collected first and attached in one go. They are looked up one by
  # one to keep the bundle's order.
  def copy_many(blob_ids, copy_attached)
    source_blobs = Array(blob_ids).filter_map { |id| ActiveStorage::Blob.find_by(id: id) }
    return if source_blobs.empty?

    copies = source_blobs.filter_map { |source_blob| copy_blob(source_blob) }
    return if copies.empty?

    copy_attached.attach(*copies)
  end

  # Image and Document are the app's polymorphic attachment wrappers. Both
  # validate the attachment for presence, so the blob has to be attached to the
  # copy before it is saved -- and a record whose blob was skipped cannot be
  # saved at all, so it is dropped rather than persisted empty.
  def copy_attachables(model, owner_key, nodes, copy, record_copier:)
    Array(nodes).each do |node|
      record_copy = record_copier.build(node, attributes: { owner_key => copy })
      copy_one(node.dig("attachments", "attachment"), record_copy.attachment)
      next if !record_copy.attachment.attached?

      record_copier.persist(node, record_copy)
    end
  end

  private

    attr_reader :id_map

    # identify: false skips the Marcel content-type sniff -- the source blob
    # already carries an identified content type.
    #
    # A blob row whose file is missing from storage raises on open. That happens
    # to any projekt old enough to have lost a file, and to every projekt on an
    # instance whose database was restored without its storage directory; it
    # must not cost the admin the entire copy.
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
    rescue ActiveStorage::FileNotFoundError
      record_skipped(source_blob)

      nil
    end

    def record_skipped(source_blob)
      Rails.logger.warn(
        "[Projekts::Copying::BlobCopier] skipped missing file for blob #{source_blob.id} " \
        "(#{source_blob.filename})"
      )

      skipped_blobs << {
        "blob_id" => source_blob.id,
        "filename" => source_blob.filename.to_s,
        "key" => source_blob.key
      }
    end
end
