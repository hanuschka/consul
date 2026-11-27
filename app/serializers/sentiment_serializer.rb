class SentimentSerializer < BaseSerializer
  def initialize(sentiment)
    @sentiment = sentiment
  end

  def serialize
    {
      id: sentiment.id,
      projekt_phase_id: sentiment.projekt_phase_id,
      name: sentiment.name,
      color: sentiment.color,
      translations: serialize_translations(sentiment),
      created_at: sentiment.created_at,
      updated_at: sentiment.updated_at
    }
  end

  private

    attr_reader :sentiment
end
