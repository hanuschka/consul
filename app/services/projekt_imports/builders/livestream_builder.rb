class ProjektImports::Builders::LivestreamBuilder < ProjektImports::Builders::Base
  def call
    Array(payload).filter_map do |livestream|
      next nil if !http_url?(livestream["url"])

      phase.projekt_livestreams.create!(
        url: livestream["url"],
        title: livestream["title"],
        description: livestream["description"],
        starts_at: livestream["starts_at"]
      )
    rescue ActiveRecord::RecordInvalid => e
      raise ProjektImports::Builders::BuilderError,
        "livestream(#{livestream["url"]}): #{e.message}"
    end
  end

  private

  # ProjektLivestream runs the url validator on this value. A model-invented URL
  # that is not http(s) is dropped here rather than failing the whole phase.
  def http_url?(value)
    return false if value.blank?

    parsed = URI.parse(value)
    parsed.is_a?(URI::HTTP) || parsed.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end
end
