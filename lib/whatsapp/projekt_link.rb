module Whatsapp::ProjektLink
  module_function

  # Title and link live together because the bot may not show one without the
  # other: a projekt named in a chat the citizen cannot open is a dead end.
  def title(projekt)
    projekt.page&.title.presence || projekt.name
  end

  # Nothing the bot links to is reached through a request, so the host comes
  # from the app's canonical URL options rather than from the caller.
  def url(projekt)
    Rails.application.routes.url_helpers.projekt_url(projekt, **UrlOptions.default.to_h)
  end

  # Built from the page slug rather than from #url, whose route redirects and
  # would drop the query string the projekt page reads to open the tab.
  def evaluation_url(projekt_phase)
    phase_url(projekt_phase, section: Whatsapp::PublishedResultsQuery.public_section_for(projekt_phase))
  end

  # Nil rather than a crash when the projekt has no page: a phase is reached
  # through its projekt's page, and callers already treat a missing link as
  # "name it without one".
  def phase_url(projekt_phase, section: nil)
    slug = projekt_phase.projekt&.page&.slug

    return if slug.blank?

    Rails.application.routes.url_helpers.page_url(
      id: slug,
      projekt_phase_id: projekt_phase.id,
      section: section,
      **UrlOptions.default.to_h
    )
  end
end
