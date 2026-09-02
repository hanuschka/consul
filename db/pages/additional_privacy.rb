unless SiteCustomization::Page.exists?(footer_key: "additional_privacy")
  existing_page = SiteCustomization::Page.where(projekt_id: nil).find_by(slug: "additional_privacy")

  if existing_page
    existing_page.update_columns(footer_key: "additional_privacy", footer_position: 2)
  else
    page = SiteCustomization::Page.new(
      slug: "additional_privacy", footer_key: "additional_privacy", footer_position: 2, status: "draft"
    )
    I18n.with_locale(:de) do
      page.title = I18n.t("adm.site_customization.pages.default_titles.additional_privacy")
      page.save!
    end
  end
end
