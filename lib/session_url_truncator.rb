module SessionUrlTruncator
  MAX_SESSION_URL_BYTES = 512

  def self.truncate(url, max_bytes: MAX_SESSION_URL_BYTES)
    return url if url.bytesize <= max_bytes

    path = url.split("?", 2).first
    return path if path.bytesize <= max_bytes

    "/"
  end
end
