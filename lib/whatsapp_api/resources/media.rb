class WhatsappApi::Resources::Media
  # Meta hands back a URL on its own CDN, but that host only accepts a Graph API
  # bearer token — which the BSP holds and we never see. Swapping the host for
  # 360dialog's makes them proxy the download against our key instead. The link
  # is valid for five minutes.
  META_MEDIA_HOST = "https://lookaside.fbsbx.com".freeze

  UPLOAD_PATH = "/media".freeze

  # HTTParty names the multipart part after the file on disk, and WhatsApp reads
  # that name when the declared type is ambiguous. Only the two types the bot
  # ever sends are here; anything else is refused before a tempfile is written.
  UPLOAD_EXTENSIONS = {
    "image/jpeg" => ".jpg",
    "image/png" => ".png"
  }.freeze

  def initialize(client)
    @client = client
  end

  def metadata(media_id)
    @client.get("/#{media_id}")
  end

  # The reverse of `download`, for a picture WhatsApp has to render before it
  # exists anywhere public: handing over the bytes gets back an id that a
  # message can carry instead of a link. A link would need our host reachable
  # from Meta's network while the send is in flight, which an access-restricted
  # environment is not.
  #
  # The bytes arrive through a block rather than as a String: the caller's
  # source is an Active Storage blob that can stream, and a picture is up to
  # HEADER_IMAGE_MAX_BYTES — holding all of it in one Ruby String only to copy
  # it into the tempfile is a whole spare copy per confirmation turn.
  #
  # Returns the media id, or nil like every other refusal here.
  def upload(mime_type:, &writer)
    return unsupported(mime_type) if !UPLOAD_EXTENSIONS.key?(mime_type)

    file = tempfile_for(mime_type, &writer)

    begin
      return empty(mime_type) if file.size.zero?

      upload_file(file, mime_type)
    ensure
      file.close
      file.unlink
    end
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

    def upload_file(file, mime_type)
      response = @client.post_multipart(
        UPLOAD_PATH,
        body: { messaging_product: "whatsapp", type: mime_type, file: file }
      )

      return refused(response) if !response.success?

      response.parsed_response.to_h["id"].presence
    end

    # Written to disk rather than kept in memory because HTTParty builds a
    # multipart part from a file handle, and reads its filename off the path.
    def tempfile_for(mime_type)
      file = Tempfile.new(["whatsapp-upload", UPLOAD_EXTENSIONS.fetch(mime_type)])
      file.binmode

      yield(file)

      file.rewind

      file
    end

    def unsupported(mime_type)
      Rails.logger.info("[Whatsapp] media upload skipped: #{mime_type} is not uploadable")

      nil
    end

    def empty(mime_type)
      Rails.logger.info("[Whatsapp] media upload skipped: nothing was written for #{mime_type}")

      nil
    end

    # The body too, not just the code: Meta answers a refused upload with the
    # reason, and without it every failure reads as a bare 400.
    def refused(response)
      Rails.logger.error(
        "[Whatsapp] media upload refused: #{response.code} - #{response.body.to_s.truncate(300)}"
      )

      nil
    end

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
