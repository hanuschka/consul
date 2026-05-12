module FileTypeIcons
  DEFAULT = "fa-file".freeze

  CONTENT_TYPE_MAP = {
    "application/pdf" => "fa-file-pdf",
    "application/msword" => "fa-file-word",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "fa-file-word",
    "application/vnd.ms-excel" => "fa-file-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => "fa-file-excel",
    "application/vnd.ms-powerpoint" => "fa-file-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" => "fa-file-powerpoint",
    "application/zip" => "fa-file-zipper",
    "application/x-rar-compressed" => "fa-file-zipper",
    "application/x-7z-compressed" => "fa-file-zipper",
    "application/json" => "fa-file-code",
    "application/xml" => "fa-file-code"
  }.freeze

  def self.for(content_type)
    return DEFAULT if content_type.blank?

    case content_type
    when %r{\Aimage/} then "fa-file-image"
    when %r{\Atext/} then "fa-file-lines"
    when %r{\Avideo/} then "fa-file-video"
    when %r{\Aaudio/} then "fa-file-audio"
    else CONTENT_TYPE_MAP[content_type] || DEFAULT
    end
  end
end
