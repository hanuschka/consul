class DocumentSerializer
  include Rails.application.routes.url_helpers

  attr_reader :document

  def initialize(document)
    @document = document
  end

  def serialize
    {
      id: document.id,
      title: document.title,
      attachment_file_name: document.attachment_file_name,
      attachment_file_size: document.attachment_file_size,
      url: download_url
    }
  end

  def self.serialize_collection(documents)
    documents.map { |document| new(document).serialize }
  end

  private

    def download_url
      return if !document.attachment.attached?

      rails_blob_url(document.attachment, **UrlOptions.default)
    end
end
