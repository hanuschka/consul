class Adm::ModuleBentoCardComponent < ApplicationComponent
  attr_reader :path, :icon, :title, :metric_text, :card_title

  def initialize(path:, icon:, title:, metric_text: nil, cta_text: nil, card_title: nil)
    @path = path
    @icon = icon
    @title = title
    @metric_text = metric_text
    @cta_text = cta_text
    @card_title = card_title
  end

  def cta_text
    @cta_text || t(".cta")
  end

  def link_title
    card_title || title
  end
end
