# Turns a link typed into a free-text field into an http(s) address. A link
# naming another scheme (javascript:, data:, mailto:) yields nil; a link
# without one gets https:// so the browser does not resolve it against the
# current page. A digit after the colon is a port, not a scheme.
module WebLink
  HTTP_SCHEME = %r{\Ahttps?://}i
  OTHER_SCHEME = /\A[a-z][a-z0-9+.\-]*:(?!\d)/i

  def self.normalize(value)
    link = value.to_s.strip
    return nil if link.blank?
    return link if link.match?(HTTP_SCHEME)
    return nil if link.match?(OTHER_SCHEME)

    "https://#{link}"
  end
end
