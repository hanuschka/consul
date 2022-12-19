class Polls::ListItem < ApplicationComponent
  attr_reader :poll

  def initialize(poll:, wide: false)
    @poll = poll
    @wide = wide
  end

  def component_attributes
    {
      resource: @poll,
      projekt: poll.projekt,
      title: poll.title,
      description: poll.summary,
      tags: poll.tags.first(3),
      sdgs: poll.related_sdgs.first(5),
      # start_date: poll.total_duration_start,
      # end_date: poll.total_duration_end,
      wide: @wide,
      resource_name: "poll",
      url: helpers.poll_path(poll),
      image_url: poll.image&.variant(:medium),
      date: poll.created_at,
      id: poll.id
    }
  end
end
