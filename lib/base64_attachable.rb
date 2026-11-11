# Turns a base64 string, bare or as a data URI, into the Hash form Active
# Storage accepts for an attachment. A bare string assigned to an attachment
# would be read as a signed blob id instead.
module Base64Attachable
  class InvalidEncoding < StandardError; end

  DATA_URI_PREFIX = %r{\Adata:(?<content_type>[\w.+-]+/[\w.+-]+)?(?:;[^,;]+)*;base64,}
  FALLBACK_FILENAME_STEM = "document".freeze

  def self.build(encoded_file, filename_stem:)
    data_uri_match = DATA_URI_PREFIX.match(encoded_file)
    payload = data_uri_match ? data_uri_match.post_match : encoded_file
    file_content = decode(payload)
    content_type =
      data_uri_match&.[](:content_type) ||
      Marcel::MimeType.for(StringIO.new(file_content))

    {
      io: StringIO.new(file_content),
      filename: "#{filename_stem.to_s.parameterize.presence || FALLBACK_FILENAME_STEM}" \
        "#{Rack::Mime::MIME_TYPES.key(content_type)}",
      content_type: content_type
    }
  end

  def self.decode(payload)
    Base64.strict_decode64(payload.gsub(/\s+/, ""))
  rescue ArgumentError
    raise InvalidEncoding, "Attachment is not valid base64."
  end
end
