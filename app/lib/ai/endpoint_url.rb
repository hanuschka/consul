module Ai::EndpointUrl
  # ruby_llm appends the request path to the configured base, so a full request
  # URL pasted from a provider portal ends up as .../responses/chat/completions
  # and every call answers 404. Longer paths come first: /chat/completions has
  # to match before /completions would leave a dangling /chat behind.
  REQUEST_PATHS = %w[/chat/completions /completions /responses /embeddings /models].freeze

  def self.normalize(url)
    trimmed_url = without_trailing_slashes(url)
    path = request_path(trimmed_url)

    return trimmed_url if path.blank?

    trimmed_url.delete_suffix(path)
  end

  def self.request_path(url)
    trimmed_url = without_trailing_slashes(url)

    REQUEST_PATHS.find { |path| trimmed_url.end_with?(path) }
  end

  # The base is joined with a request path, so a query or fragment would land
  # in the middle of every request URL.
  def self.valid?(url)
    uri = URI.parse(url.to_s)

    uri.is_a?(URI::HTTP) && uri.host.present? && uri.query.nil? && uri.fragment.nil?
  rescue URI::InvalidURIError
    false
  end

  def self.without_trailing_slashes(url)
    url.to_s.strip.sub(%r{/+\z}, "")
  end
end
