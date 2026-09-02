# Bridges Active Storage to the extractors, which take an UploadedFile because
# they need a real path on disk. The blob is streamed to a tempfile that only
# lives for the duration of the block.
module AttachmentUpload
  def self.open(attachment)
    attachment.blob.open do |tempfile|
      yield ActionDispatch::Http::UploadedFile.new(
        tempfile: tempfile,
        filename: attachment.blob.filename.to_s,
        type: attachment.blob.content_type
      )
    end
  end
end
