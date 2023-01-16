# frozen_string_literal: true

class Projekts::ProjektEvents::ListItem < ApplicationComponent
  attr_reader :projekt_event

  def initialize(projekt_event:, show_projekt_link: false, wide: false)
    @projekt_event = projekt_event
    @show_projekt_link = show_projekt_link
    @wide = false
  end

  def component_attributes
    {
      resource: @projekt_event,
      head_title: @projekt_event.category.name,
      title: projekt_event.title,
      description: projekt_event.summary,
      tags: projekt_event.tags.first(3),
      # sdgs: projekt_event.related_sdgs.first(5),
      # start_date: projekt_event.total_duration_start,
      # end_date: projekt_event.total_duration_end,
      wide: @wide,
      url: helpers.deficiency_report_path(projekt_event),
      image_url: projekt_event.image&.variant(:medium),
      date: projekt_event.created_at,
      author: projekt_event.author,
      image_placeholder_icon_class: "fa-calendar-alt",
      id: projekt_event.id
    }
  end
end
