class WhatsappApi::Resources::Media
  # Meta hands back a URL on its own CDN, but that host only accepts a Graph API
  # bearer token — which the BSP holds and we never see. Swapping the host for
  # 360dialog's makes them proxy the download against our key instead. The link
  # is valid for five minutes.
  META_MEDIA_HOST = "https://lookaside.fbsbx.com".freeze

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

    return oversize(media_id, file_size, max_bytes) if file_size > max_bytes
    return if payload["url"].blank?

    binary = @client.download(proxied_url(payload["url"]))

    return if !binary.success?
    return oversize(media_id, binary.body.to_s.bytesize, max_bytes) if
      binary.body.to_s.bytesize > max_bytes

    {
      body: binary.body,
      mime_type: payload["mime_type"],
      file_size: file_size
    }
  end

  private

    def proxied_url(url)
      url.to_s.sub(META_MEDIA_HOST, ::Whatsapp.base_url.to_s.chomp("/"))
    end

    # Returns nil like every other refusal, but says why: a silent size refusal
    # is indistinguishable from a failed download in the logs.
    def oversize(media_id, bytes, max_bytes)
      Rails.logger.info(
        "[Whatsapp] media #{media_id} skipped: #{bytes} bytes exceeds #{max_bytes}"
      )

      nil
    end
end
