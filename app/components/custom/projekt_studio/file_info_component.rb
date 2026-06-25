class ProjektStudio::FileInfoComponent < Files::ResourceAssetComponent
  def initialize(
    title:,
    filename:,
    content_type:,
    file_size:,
    file_url:,
    created_at:,
    updated_at:,
    user_name: nil,
    user_email: nil,
    projekt: nil,
    dimensions: nil,
    preview_url: nil
  )
    @title = title
    @filename = filename
    @content_type = content_type
    @file_size = file_size
    @file_url = file_url
    @created_at = created_at
    @updated_at = updated_at
    @user_name = user_name
    @user_email = user_email
    @projekt = projekt
    @dimensions = dimensions
    @preview_url = preview_url
  end

  private

    attr_reader :title, :filename, :content_type, :file_size, :file_url,
                :created_at, :updated_at, :user_name, :user_email,
                :projekt, :dimensions, :preview_url

    def humanized_size
      return "" if file_size.blank?

      helpers.number_to_human_size(file_size)
    end

    def created_at_formatted
      I18n.l(created_at, format: :short)
    end

    def updated_at_formatted
      I18n.l(updated_at, format: :short)
    end

    def uploader_text
      [user_name, user_email].compact_blank.join(" · ")
    end

    def projekt_name
      resource_name(projekt)
    end

    def projekt_url
      resource_url(projekt)
    end
end
