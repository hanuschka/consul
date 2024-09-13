# frozen_string_literal: true

class Polls::ListItemComponent < ApplicationComponent
  delegate :link_to_poll, to: :helpers
  attr_reader :poll

  def initialize(poll:)
    @poll = poll
  end

  def component_attributes
    {
      resource: @poll,
      projekt: poll.projekt,
      title: poll.title,
      description: (poll.summary.presence || poll.description),
      url: helpers.poll_path(poll),
      image_url: poll.image&.variant(:card_thumb),
      image_placeholder_icon_class: "fa-vote-yea"
    }
  end

  private

    def button_text
      if poll.current? || poll.expired?
        t("custom.polls.poll.phase_expired_button")
      else
        t("custom.polls.poll.phase_not_started_button")
      end
    end
end
