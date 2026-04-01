class Adm::SiteCustomization::ContentCardsComponent < ApplicationComponent
  def initialize(landing_page_id: nil)
    @landing_page_id = landing_page_id
  end

  def content_cards
    ::SiteCustomization::ContentCard.get_or_create(landing_page_id: @landing_page_id)
  end
end
