class Debates::ListItem::Component < ApplicationComponent
  attr_reader :debate

  def initialize(debate:, wide: false)
    @debate = debate
    @wide = wide
  end

  def component_attributes
    {
      resource: @debate,
      head_title: debate.projekt&.page&.title,
      title: debate.title,
      description: debate.description,
      tags: debate.tags.first(3),
      sdgs: debate.related_sdgs.first(5),
      # start_date: debate.total_duration_start,
      # end_date: debate.total_duration_end,
      wide: @wide,
      resource_name: "Debate",
      url: helpers.proposals_path(debate),
      image_url: debate.image&.variant(:medium),
      date: debate.created_at,
      author: debate.author,
      id: debate.id
    }
  end
end
