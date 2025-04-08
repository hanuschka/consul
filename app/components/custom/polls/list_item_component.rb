# frozen_string_literal: true

class Polls::ListItemComponent < ApplicationComponent
  delegate :link_to_poll, to: :helpers
  attr_reader :poll, :projekt_phase

  def initialize(poll:, additional_url_params: nil)
    @poll = poll
    @projekt_phase = poll.projekt_phase
    @additional_url_params = additional_url_params
  end

  def component_attributes
    {
      resource: @poll,
      projekt: poll.projekt,
      title: poll.title,
      description: projekt_phase.description,
      url: poll_path,
      image_url: poll.image&.variant(:card_thumb),
      image_placeholder_icon_class: "fa-vote-yea"
    }
  end

  private

    def poll_path
      base_url = helpers.poll_path(poll.id)

      if @additional_url_params.present?
        base_url = UrlUtils.add_params_to_url(base_url, @additional_url_params)
      end

      base_url
    end

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
