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
      if @additional_url_params.present? && @additional_url_params[:landing_page].present?
        helpers.landing_page_poll_path(
          landing_page_slug: @additional_url_params[:landing_page],
          id: poll.id
        )
      else
        helpers.poll_path(poll.id)
      end
    end

    def button_text
      if poll&.projekt_phase&.current?
        poll&.projekt_phase&.cta_button_name.presence ||
          t("custom.polls.poll.phase_current_button")
      elsif poll&.projekt_phase&.expired?
        poll&.projekt_phase&.cta_button_name.presence ||
          t("custom.polls.poll.phase_expired_button")
      else
        t("custom.polls.poll.phase_not_started_button")
      end
    end
end
