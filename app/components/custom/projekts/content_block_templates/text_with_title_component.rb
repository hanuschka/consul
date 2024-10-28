class Projekts::ContentBlockTemplates::TextWithTitleComponent < ViewComponent::Base
  def initialize(text:, title:)
    @text = text
    @title = title
  end

  def render?
    @text.present?
  end
end
