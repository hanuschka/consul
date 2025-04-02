class Ckeditor::Asset < ApplicationRecord
  include Searchable
  include Rails.application.routes.url_helpers

  EDITORS_WITH_FULL_URL = %w[newsletter_body].freeze

  self.table_name = "ckeditor_assets"

  has_one_attached :storage_data

  def self.search(terms)
    pg_search(terms)
  end

  def attach_uploaded_file(data)
    return unless data.is_a?(ActionDispatch::Http::UploadedFile)

    storage_data.attach(io: data, filename: data.original_filename, content_type: data.content_type)

    self.data_file_name = data.original_filename
    self.data_content_type = data.content_type
    self.data_file_size = data.size
    self.type = type
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
