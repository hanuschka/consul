module Whatsapp::PortalLinks
  # The catalog's copy names one city and four of its URLs. Everything
  # tenant-specific is resolved here instead of being written into the
  # translations, so the same wording reads correctly on every portal running
  # this codebase.
  #
  # Page slugs are candidate lists for the same reason
  # Whatsapp::Archive::SendStaticPageService used them: admins name the page in
  # their own language, and the bot must link whichever one exists rather than
  # inventing a second copy of it.
  PAGE_SLUGS = {
    privacy: %w[datenschutz privacy privacy-policy datenschutzerklaerung],
    help: %w[hilfe help],
    conditions: %w[nutzungsbedingungen conditions terms]
  }.freeze

  module_function

  def portal_name
    Setting["org_name"].presence || I18n.t("whatsapp.bot.portal_fallback_name")
  end

  def root_url
    Rails.application.routes.url_helpers.root_url(**UrlOptions.default.to_h)
  end

  # The overview tab a browsed category came from, so "and N more" lands on
  # the same list the bot just quoted. `filter` rather than `order`: it is
  # ProjektsController#index that reads the parameter, and it whitelists
  # params[:filter] against its own INDEX_FILTERS.
  def projekts_url(filter:)
    Rails.application.routes.url_helpers.projekts_url(filter: filter, **UrlOptions.default.to_h)
  end

  def register_url
    Rails.application.routes.url_helpers.new_user_registration_url(**UrlOptions.default.to_h)
  end

  def privacy_url
    page_url(:privacy)
  end

  def help_url
    page_url(:help)
  end

  def conditions_url
    page_url(:conditions)
  end

  # Falls back to the portal's front page rather than to a dead link: a consent
  # line that points somewhere useful is better than one that points at a 404,
  # and better than one that silently drops the URL it promised.
  def page_url(key)
    page = published_page(key)

    return root_url if page.blank?

    Rails.application.routes.url_helpers.page_url(id: page.slug, **UrlOptions.default.to_h)
  end

  def published_page(key)
    SiteCustomization::Page
      .where(status: "published", slug: PAGE_SLUGS.fetch(key))
      .first
  end
end
