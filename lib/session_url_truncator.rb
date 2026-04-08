module SessionUrlTruncator
  MAX_SESSION_URL_BYTES = 512

  def self.truncate(url, max_bytes: MAX_SESSION_URL_BYTES)
    return url if url.bytesize <= max_bytes

    url.split("?", 2).first
  end
end
