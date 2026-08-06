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
    Rails.application.routes.url_helpers.page_url(
      id: projekt_phase.projekt.page.slug,
      projekt_phase_id: projekt_phase.id,
      section: WhatsappPublishedResultsQuery.public_section_for(projekt_phase),
      **UrlOptions.default.to_h
    )
  end
end
