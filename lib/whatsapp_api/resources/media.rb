class WhatsappApi::Resources::Media
  def initialize(client)
    @client = client
  end

  def metadata(media_id)
    @client.get("/#{media_id}")
  end

  # The Cloud API audio object carries no duration, so the size reported by the
  # media endpoint is the only budget available before spending the download.
  def download(media_id, max_bytes:)
    media = metadata(media_id)

    return if !media.success?

    payload = media.parsed_response.to_h
    file_size = payload["file_size"].to_i

    return if file_size > max_bytes
    return if payload["url"].blank?

    binary = @client.download(payload["url"])

    return if !binary.success?
    return if binary.body.to_s.bytesize > max_bytes

    {
      body: binary.body,
      mime_type: payload["mime_type"],
      file_size: file_size
    }
  end
end
