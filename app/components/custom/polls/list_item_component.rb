# frozen_string_literal: true

class Polls::ListItemComponent < ApplicationComponent
  delegate :link_to_poll, to: :helpers
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

  private

    def button_text
      if poll&.projekt_phase&.current?
        t("custom.polls.poll.phase_current_button")
      elsif poll&.projekt_phase&.expired?
        t("custom.polls.poll.phase_expired_button")
      else
        t("custom.polls.poll.phase_not_started_button")
      end
    end
end
