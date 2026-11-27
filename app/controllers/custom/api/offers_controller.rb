class Api::OffersController < Api::BaseController
  before_action :check_read_access!
  before_action :check_module_enabled!

  def index
    offers = paginate(published_offers.sort_by_title)

    render json: {
      data: { offers: OfferSerializer.serialize_collection(offers) },
      pagination: pagination_meta(offers)
    }
  end

  def show
    offer = published_offers.find(params[:id])

    render json: { data: { offer: OfferSerializer.new(offer).serialize }}
  end

  private

    def published_offers
      Offer.published.includes(:translations, :provider, :map_location, :image,
                               categories: :translations)
    end

    def check_module_enabled!
      raise ActiveRecord::RecordNotFound if Setting["process.offers"].blank?
    end
end
