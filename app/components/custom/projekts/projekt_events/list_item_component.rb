# frozen_string_literal: true

class Projekts::ProjektEvents::ListItemComponent < ApplicationComponent
  attr_reader :projekt_event

  def initialize(projekt_event:, hide_projekt_breadcrumb: false)
    @projekt_event = projekt_event
    @hide_projekt_breadcrumb = hide_projekt_breadcrumb
  end

  def component_attributes
    {
      resource: projekt_event,
      projekt: projekt_event.projekt,
      hide_projekt_breadcrumb: @hide_projekt_breadcrumb,
      title: projekt_event.title,
      description: projekt_event.description,
      image: projekt_event.image,
      image_placeholder_icon_class: "fa-comments",
      no_footer_bottom_padding: true
    }
  end
end
