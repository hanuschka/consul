class Projekts::ContentBlockTemplates::AccordionComponent < ViewComponent::Base
  def initialize(title:, items:)
    @title = title
    @items = items
  end

  def render?
    @items.present?
  end
end
