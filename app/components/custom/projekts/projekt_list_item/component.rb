class Projekts::ProjektListItem::Component < ApplicationComponent
  attr_reader :projekt

  def initialize(projekt:, wide: false)
    @projekt = projekt
    @wide = wide
  end

  def component_attributes
    {
      resource: @projekt,
      title: projekt.page.title,
      description: projekt.description,
      tags: projekt.tags.first(3),
      sdgs: projekt.related_sdgs.first(5),
      start_date: projekt.total_duration_start,
      end_date: projekt.total_duration_end,
      resource_name: "Projekt",
      wide: @wide,
      url: projekt.page.url,
      image_url: projekt.image&.variant(:medium),
      id: projekt.id
    }
  end
end