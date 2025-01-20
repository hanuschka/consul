class Ckeditor::Picture < Ckeditor::Asset
  ALLOWED_CONTENT_TYPES = %w[image/jpg image/jpeg image/png image/gif].freeze

  def url_content(editor_id: nil)
    file_path = rails_representation_url(
      storage_data.variant(coalesce: true, resize: "800>", loader: { page: nil }), only_path: true
    )

    absolute_path?(editor_id) ? Setting["url"] + file_path : file_path
  end

  def url_thumb(editor_id: nil)
    file_path = rails_representation_url(
      storage_data.variant(coalesce: true, resize: "118x100", loader: { page: nil }), only_path: true
    )

    absolute_path?(editor_id) ? Setting["url"] + file_path : file_path
  end

  def type
    "Ckeditor::Picture"
  end
end
