class OfferSerializer < BaseSerializer
  attr_reader :offer

  def initialize(offer)
    @offer = offer
  end

  def serialize
    {
      id: offer.id,
      title: offer.title,
      short_description: offer.short_description,
      times: offer.times,
      costs: offer.costs,
      registration: offer.registration,
      address: offer.address,
      contact_name: offer.contact_name,
      contact_phone: offer.contact_phone,
      contact_email: offer.contact_email,
      contact_website: offer.contact_website,
      expires_on: offer.expires_on,
      updated_at: offer.updated_at,
      provider: serialize_provider,
      categories: serialize_categories,
      map_location: serialize_map_location,
      image: serialize_image
    }
  end

  private

    def serialize_provider
      return if offer.provider.blank?

      { id: offer.provider.id, name: offer.provider.name }
    end

    def serialize_categories
      Offer::Category::KINDS.index_with do |kind|
        offer.categories_of(kind).map { |category| { id: category.id, name: category.name } }
      end
    end

    def serialize_map_location
      map_location = offer.map_location
      return if map_location.blank? || map_location.latitude.blank? || map_location.longitude.blank?

      { latitude: map_location.latitude, longitude: map_location.longitude }
    end

    def serialize_image
      return if offer.image.blank?

      ImageSerializer.new(offer.image, include_variants: false).serialize
    end
end
