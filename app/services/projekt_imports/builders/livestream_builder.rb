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

  # ProjektLivestream runs UrlValidator on this value. Asking the validator
  # itself keeps the two in step instead of copying its predicate, so a
  # model-invented URL is dropped here rather than failing the whole phase.
  def http_url?(value)
    return false if !value.is_a?(String)
    return false if value.blank?

    UrlValidator.new(attributes: [:url]).url_valid?(value)
  end
end
