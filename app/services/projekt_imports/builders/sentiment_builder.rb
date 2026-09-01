class ProjektImports::Builders::SentimentBuilder < ProjektImports::Builders::Base
  DEFAULT_COLOR = "#3366CC".freeze

  def call
    Array(payload).filter_map do |sentiment|
      name = sentiment["name"].to_s.strip
      next nil if name.blank?

      phase.sentiments.create!(name: name, color: hex_color(sentiment["color"]))
    rescue ActiveRecord::RecordInvalid => e
      raise ProjektImports::Builders::BuilderError, "sentiment(#{name}): #{e.message}"
    end
  end

  private

  # The citizen form renders the color as an inline background and derives the
  # text color from it, so a missing or malformed value would break the chip.
  def hex_color(color)
    normalized = color.to_s.strip
    return DEFAULT_COLOR if !normalized.match?(/\A#(\h{3}|\h{6})\z/)

    normalized
  end
end
