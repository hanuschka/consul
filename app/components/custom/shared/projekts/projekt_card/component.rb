class Shared::Projekts::ProjektCard::Component < ApplicationComponent
  attr_reader :projekt

  def initialize(projekt:, wide: false)
    @projekt = projekt
    @wide = wide
  end

  def component_attributes
    {
      title: projekt.page.title,
      description: projekt.description,
      tags: projekt.tags.first(3),
      start_date: projekt.total_duration_start,
      end_date: projekt.total_duration_end,
      wide: @wide,
      image_url: projekt.image&.variant(:medium),
      id: projekt.id
    }
  end
end
