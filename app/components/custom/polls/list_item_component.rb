# frozen_string_literal: true

class Polls::ListItemComponent < ApplicationComponent
  attr_reader :poll, :projekt_phase

  def initialize(poll:)
    @poll = poll
    @projekt_phase = poll.projekt_phase
  end

  def component_attributes
    {
      resource: @poll,
      projekt: poll.projekt,
      title: poll.title,
      description: projekt_phase.description,
      url: helpers.poll_path(poll.id),
      image_url: poll.image&.variant(:card_thumb),
      image_placeholder_icon_class: "fa-vote-yea"
    }
  end
end
