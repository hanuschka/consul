# frozen_string_literal: true

class Polls::ListItemComponent < ApplicationComponent
  delegate :link_to_poll, to: :helpers
  attr_reader :poll, :projekt_phase

  def initialize(poll:, hide_projekt_breadcrumb: false)
    @poll = poll
    @hide_projekt_breadcrumb = hide_projekt_breadcrumb
    @projekt_phase = poll.projekt_phase
  end

  def component_attributes
    {
      resource: @poll,
      projekt: @hide_projekt_breadcrumb ? nil : poll.projekt,
      title: poll.title,
      description: projekt_phase.description,
      url: poll_path
    }
  end

  private

    def poll_path
      helpers.poll_path(poll.id)
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
