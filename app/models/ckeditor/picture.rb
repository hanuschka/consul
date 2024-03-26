class Ckeditor::Picture < Ckeditor::Asset
  EDITORS_WITH_FULL_URL = %w[newsletter_body].freeze

  attr_accessor :data
  has_one_attached :storage_data

  validates :storage_data, file_content_type: { allow: /^image\/.*/ }, file_size: { less_than: 2.megabytes }

  def url_content(editor_id: nil)
    if absolute_path?(editor_id)
      Setting["url"] + rails_representation_url(storage_data.variant(resize: "800>"), only_path: true)
    else
      rails_representation_url(storage_data.variant(resize: "800>"), only_path: true)
    end
  end

  def url_thumb
    rails_representation_url(storage_data.variant(resize: "118x100"), only_path: true)
  end

  private

    def absolute_path?(editor_id)
      editor_id.present? && EDITORS_WITH_FULL_URL.include?(editor_id)
    end
end
