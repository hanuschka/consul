module Images::AiMarker
  # The read side of the AI marking: whether a picture's bytes actually carry
  # the IPTC source type that says a machine made it.
  #
  # Separate from Images::MarkAiGeneratedService, which writes it, because three
  # callers ask the question for three different reasons — the Image model
  # deciding whether to trust a form's claim, the backfill deciding whether a
  # picture still needs marking, and the audit counting the ones that do. The
  # tag is what they have to agree on, and one reader is how they cannot drift.
  #
  # The bytes are the authority rather than the record's flags: a flag can be
  # set over a file that was never marked, which is exactly the state these
  # callers exist to detect.
  module_function

  def marker_in?(bytes, extension: ".jpg")
    return false if bytes.blank?

    file = Tempfile.new(["ai_marker_read", extension], binmode: true)

    begin
      file.write(bytes)
      file.flush

      marker_at?(file.path)
    ensure
      file.close
      file.unlink
    end
  end

  def marker_at?(path)
    ::ExiftoolCommand.read_tag(
      path, ::Images::MarkAiGeneratedService::DIGITAL_SOURCE_TYPE_TAG
    ) == ::Images::MarkAiGeneratedService::TRAINED_ALGORITHMIC_MEDIA
  end
end
