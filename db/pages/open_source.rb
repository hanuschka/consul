unless SiteCustomization::Page.exists?(footer_key: "open_source")
  existing_page = SiteCustomization::Page.where(projekt_id: nil).find_by(slug: "open_source")

  if existing_page
    existing_page.update_columns(footer_key: "open_source", footer_position: 8)
  else
    page = SiteCustomization::Page.new(slug: "open_source", footer_key: "open_source", footer_position: 8,
                                       status: "draft")
    I18n.with_locale(:de) do
      page.title = I18n.t("adm.site_customization.pages.default_titles.open_source")
      page.save!
    end
  end
end
