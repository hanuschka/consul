unless SiteCustomization::Page.exists?(footer_key: "netiquette")
  existing_page = SiteCustomization::Page.where(projekt_id: nil).find_by(slug: "netiquette")

  if existing_page
    existing_page.update_columns(footer_key: "netiquette", footer_position: 6)
  else
    page = SiteCustomization::Page.new(slug: "netiquette", footer_key: "netiquette", footer_position: 6,
                                       status: "draft")
    I18n.with_locale(:de) do
      page.title = I18n.t("adm.site_customization.pages.default_titles.netiquette")
      page.save!
    end
  end
end
