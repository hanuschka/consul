class Projekts::ContentBlockTemplates::TextComponent < ViewComponent::Base
  def initialize(text:)
    @text = text
  end
end
