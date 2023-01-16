class ProjektEvents::ListItem < ApplicationComponent
  TIME_FORMAT = "%H:%M".freeze

  attr_reader :projekt_event

  def initialize(projekt_event:, wide: false)
    @projekt_event = projekt_event
    @wide = wide
  end

  def component_attributes
    {
      resource: @projekt_event,
      head_title: format_time,
      title: projekt_event.title,
      description: "event description",
      # tags: projekt_event.tags.first(3),
      # sdgs: projekt_event.related_sdgs.first(5),
      # start_date: projekt_event.total_duration_start,
      # end_date: projekt_event.total_duration_end,
      wide: @wide,
      # url: helpers.projekt_events_path(projekt_event),
      # image_url: projekt_event.image&.variant(:medium),
      date: projekt_event.created_at,
      # author: projekt_event.author,
      image_placeholder_icon_class: "fa-calendar-alt",
      id: projekt_event.id
    }
  end

  def format_time
    if projekt_event.end_datetime.present?
      "#{start_time_formated} Uhr bis #{end_time_formated} Uhr"
    else
      start_time_formated
    end
  end

  def start_time_formated
    projekt_event.datetime.strftime(TIME_FORMAT)
  end

  def end_time_formated
    projekt_event.end_datetime.strftime(TIME_FORMAT)
  end
end
