class Files::ImageCardComponent < ApplicationComponent
  with_collection_parameter :image

  def initialize(image:, type:)
    @image = image
    @type = type
  end

  private

    attr_reader :image, :type

    def filename
      attachment_filename.presence || image.title.presence || "Untitled"
    end

    def display_title
      image.title.presence || filename
    end

    def attachment_filename
      if !attached?
        return ""
      end

      image.attachment.filename.to_s
    end

    def attachment_byte_size
      if !attached?
        return nil
      end

      image.attachment.byte_size
    end

    def humanized_size
      bytes = attachment_byte_size
      return "" if bytes.blank?

      helpers.number_to_human_size(bytes)
    end

    def created_at_formatted
      I18n.l(image.created_at, format: :short)
    end

    def updated_at_formatted
      I18n.l(image.updated_at, format: :short)
    end

    def attachment_metadata
      if !attached?
        return {}
      end

      image.attachment.metadata || {}
    end

    def dimensions
      meta = attachment_metadata
      width = meta[:width] || meta["width"]
      height = meta[:height] || meta["height"]

      if width.blank? || height.blank?
        return ""
      end

      "#{width} × #{height}"
    end

    def thumb_url
      if !attached?
        return ""
      end

      helpers.rails_representation_url(
        image.variant(:card_thumb), only_path: true
      )
    rescue StandardError
      helpers.url_for(image.attachment)
    end

    def original_url
      if !attached?
        return ""
      end

      helpers.url_for(image.attachment)
    end

    def imageable_type_label
      type_string = image.imageable_type.to_s
      type_string.safe_constantize&.model_name&.human || type_string
    end

    def update_url
      helpers.adm_files_image_path(image)
    end

    def attached?
      image.attachment.attached?
    end
end
