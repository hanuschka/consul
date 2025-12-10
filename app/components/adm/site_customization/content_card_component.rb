class Adm::SiteCustomization::ContentCardComponent < ApplicationComponent
  def initialize(content_card, updated: false)
    @content_card = content_card
    @updated = updated
  end

  def count
    if @content_card.settings["limit"].present?
      @content_card.settings["limit"]
    elsif @content_card.settings.keys.any? { |key| key.match?("limit") }
      t(".mixed_number")
    end
  end
end
