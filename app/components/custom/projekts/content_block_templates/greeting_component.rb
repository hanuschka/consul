class Projekts::ContentBlockTemplates::GreetingComponent < ViewComponent::Base
  def initialize(text:, title:, quote:, image_url:)
    @title = title
    @text = text
    @quote = quote
    @image_url = image_url
  end

  def render?
    @text.present?
  end
end
