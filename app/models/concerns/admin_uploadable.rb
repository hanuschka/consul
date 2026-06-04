module AdminUploadable
  extend ActiveSupport::Concern

  EDITORS_WITH_FULL_URL = %w[newsletter_body].freeze

  included do
    include Searchable
    include Rails.application.routes.url_helpers

    belongs_to :projekt, optional: true

    has_one_attached :storage_data
  end

  class_methods do
    def search(terms)
      pg_search(terms)
    end
  end

  def attach_uploaded_file(data, custom_image = nil)
    return unless data.is_a?(ActionDispatch::Http::UploadedFile)

    image_to_store = custom_image.presence || data
    storage_data.attach(io: image_to_store, filename: data.original_filename, content_type: data.content_type)

    self.data_file_name = data.original_filename
    self.data_content_type = data.content_type
    self.data_file_size = image_to_store.size
    self.title = data.original_filename
  end

  def searchable_values
    {
      title => "A",
      description => "B"
    }
  end

  private

    def absolute_path?(editor_id)
      editor_id.present? && EDITORS_WITH_FULL_URL.include?(editor_id)
    end
end
