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
    conditions: %w[nutzungsbedingungen conditions terms],
    contact: %w[kontakt contact contact_us kontaktieren-sie-uns contact-us]
  }.freeze

  # The footer's own identity for a page, which is asked first: an admin may
  # rename a slug, and the footer still finds the page by this key while the
  # slug list above would silently fall back to the front page. The slugs stay
  # the fallback for pages created before the key existed.
  FOOTER_KEYS = {
    privacy: "privacy",
    conditions: "conditions",
    contact: "contact_us"
  }.freeze

  module_function

  def portal_name
    Setting["org_name"].presence || ::Whatsapp.copy("whatsapp.bot.portal_fallback_name")
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

  # Where an erasure is actually asked for, as against severing the WhatsApp link,
  # which detaches a number and removes nothing. A route helper rather than a page
  # slug: this form is part of the application, so there is no admin-named page for
  # it to be missing and no fallback to the front page to make.
  def delete_account_url
    Rails.application.routes.url_helpers.users_registrations_delete_form_url(
      **UrlOptions.default.to_h
    )
  end

  def privacy_url(locale: nil)
    page_url(:privacy, locale: locale)
  end

  def help_url(locale: nil)
    page_url(:help, locale: locale)
  end

  def conditions_url(locale: nil)
    page_url(:conditions, locale: locale)
  end

  def contact_url(locale: nil)
    page_url(:contact, locale: locale)
  end

  # Falls back to the portal's front page rather than to a dead link: a consent
  # line that points somewhere useful is better than one that points at a 404,
  # and better than one that silently drops the URL it promised.
  def page_url(key, locale: nil)
    page = published_page(key)
    url_helpers = Rails.application.routes.url_helpers
    options = { **locale_params(locale), **UrlOptions.default.to_h }

    return url_helpers.root_url(**options) if page.blank?

    url_helpers.page_url(id: page.slug, **options)
  end

  def published_page(key)
    published = SiteCustomization::Page.where(status: "published")
    footer_key = FOOTER_KEYS[key]
    by_footer_key = footer_key.present? ? published.find_by(footer_key: footer_key) : nil

    by_footer_key || published.where(slug: PAGE_SLUGS.fetch(key)).first
  end

  # The language the citizen is chatting in, carried to the page so it opens in
  # that language rather than in whatever the browser or an old session says.
  # Only where it differs from the portal's own, which the page opens in anyway,
  # and only for a locale the portal has.
  def locale_params(locale)
    requested = locale.to_s

    return {} if requested.blank?
    return {} if requested == I18n.default_locale.to_s
    return {} if I18n.available_locales.map(&:to_s).exclude?(requested)

    { locale: requested }
  end
end
