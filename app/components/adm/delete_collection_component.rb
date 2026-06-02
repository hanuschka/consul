class Adm::DeleteCollectionComponent < ApplicationComponent
  def initialize(
    url:,
    text:,
    confirm:,
    status_url:,
    initial_status: nil,
    headline: nil,
    hint: nil,
    icon: "delete",
    style: :danger,
    wrapper_classes: "d-flex justify-content-end align-items-center gap-3"
  )
    @url = url
    @text = text
    @confirm = confirm
    @status_url = status_url
    @initial_status = initial_status
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

  attr_reader :url, :text, :confirm, :status_url, :initial_status, :icon, :style, :wrapper_classes
end
