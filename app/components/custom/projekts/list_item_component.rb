# frozen_string_literal: true

class Projekts::ListItemComponent < ApplicationComponent
  attr_reader :projekt

  delegate :projekt_option, to: :helpers

  def initialize(projekt:)
    @projekt = projekt
  end

  def component_attributes
    {
      resource: projekt,
      title: projekt.page.title,
      description: strip_tags(projekt.page.subtitle),
      tags: projekt.tags,
      narrow_header: true,
      url: projekt_url,
      url_target: url_target,
      image_url: image_url
    }
  end

  def projekt_phase_url_for(phase)
    return poll_url(phase.poll) if phase.is_a?(ProjektPhase::VotingPhase) && phase.poll.present?

    "#{projekt.page.url}?projekt_phase_id=#{phase.id}#projekt-footer"
  end

  def date_formated
    base_formated_date = helpers.format_date_range(projekt.total_duration_start, projekt.total_duration_end)

    base_formated_date.presence || "Fortlaufendes Projekt"
  end

  def phase_icon_class(phase)
    helpers.phase_icon_class(phase)
  end

  def projekt_url
    projekt_option(projekt, "general.external_participation_link").presence || projekt.page.url
  end

  def url_target
    "_blank" if projekt_option(projekt, "general.external_participation_link").present?
  end

  def image_url
    projekt.image&.attachment&.variant(resize_to_limit: [298, 180], saver: { quality: 85 }, format: 'jpeg')
  end
end
