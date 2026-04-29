class Adm::DeleteProgressComponent < ApplicationComponent
  def initialize(
    url:,
    text:,
    confirm:,
    headline: nil,
    hint: nil,
    icon: "delete",
    style: :danger,
    wrapper_classes: "d-flex justify-content-end align-items-center gap-3"
  )
    @url = url
    @text = text
    @confirm = confirm
    @headline = headline
    @hint = hint
    @icon = icon
    @style = style
    @wrapper_classes = wrapper_classes
  end

  def headline
    @headline.presence || t(".default_headline")
  end

  def hint
    @hint.presence || t(".default_hint")
  end

  attr_reader :url, :text, :confirm, :icon, :style, :wrapper_classes
end
