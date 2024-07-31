# frozen_string_literal: true

class Projekts::ProjektEvents::ListItemComponent < ApplicationComponent
  attr_reader :projekt_event

  def initialize(projekt_event:)
    @projekt_event = projekt_event
  end

  def component_attributes
    {
      resource: projekt_event,
      projekt: projekt_event.projekt,
      title: projekt_event.title,
      description: projekt_event.description,
      image_placeholder_icon_class: "fa-comments",
      no_footer_bottom_padding: true
    }
  end
end
