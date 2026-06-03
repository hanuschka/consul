class Files::FilterBarComponent < ApplicationComponent
  SORT_OPTIONS = %w[
    created_desc created_asc updated_desc updated_asc
    name_asc name_desc size_asc size_desc
  ].freeze

  PICTURE_EXTENSIONS = %w[jpg jpeg png gif webp svg].freeze

  DOCUMENT_EXTENSIONS = %w[pdf doc docx xls xlsx ppt pptx odt ods txt csv rtf].freeze

  def initialize(type: nil, imageable_type_frame_src: nil, documentable_type_frame_src: nil, minimal: false, show_view_modes: false)
    @type = type
    @imageable_type_frame_src = imageable_type_frame_src
    @documentable_type_frame_src = documentable_type_frame_src
    @minimal = minimal
    @show_view_modes = show_view_modes
  end

  private

    attr_reader :type, :imageable_type_frame_src, :documentable_type_frame_src, :minimal, :show_view_modes

    def minimal?
      minimal
    end

    def show_view_modes?
      show_view_modes
    end

    def extension_options
      case type
      when "picture" then PICTURE_EXTENSIONS
      when "document" then DOCUMENT_EXTENSIONS
      else PICTURE_EXTENSIONS + DOCUMENT_EXTENSIONS
      end
    end
end
