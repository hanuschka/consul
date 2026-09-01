class Sidebar::DocumentListComponent < ApplicationComponent
  def initialize(documents:)
    @documents = documents
  end

  private

    def display_title(document)
      title = document.title.to_s
      extension = File.extname(document.attachment.filename.to_s)

      if extension.present? && title.downcase.end_with?(extension.downcase)
        title[0...-extension.length].presence || title
      else
        title
      end
    end

    def icon_class(document)
      FileTypeIcons.for(document.attachment.content_type)
    end

    def type_label(document)
      extension = File.extname(document.attachment.filename.to_s).delete(".")
      return extension.upcase if extension.present?

      document.attachment.content_type.to_s.split("/").last&.upcase
    end

    def human_size(document)
      helpers.number_to_human_size(document.attachment.byte_size)
    end

    def meta_text(document)
      [type_label(document), human_size(document)].select(&:present?).join(" · ")
    end
end
