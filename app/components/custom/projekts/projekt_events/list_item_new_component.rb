# frozen_string_literal: true

class Projekts::ProjektEvents::ListItemNewComponent < ApplicationComponent
  delegate :render_image, :current_user, to: :helpers

  attr_reader :projekt_event

  def initialize(projekt_event:, show_projekt_link: false)
    @projekt_event = projekt_event
    @show_projekt_link = show_projekt_link
  end

  private

    def weblink_url
      @weblink_url ||= projekt_event.weblink_url
    end
end
