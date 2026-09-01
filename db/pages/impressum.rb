unless SiteCustomization::Page.exists?(footer_key: "impressum")
  page = SiteCustomization::Page.new(slug: "impressum", footer_key: "impressum", footer_position: 5,
                                     status: "published")
  page.print_content_flag = true
  page.title = I18n.t("custom.pages.impressum.title")
  page.save!
end
