unless SiteCustomization::Page.exists?(footer_key: "contact_us")
  page = SiteCustomization::Page.new(slug: "contact_us", footer_key: "contact_us", footer_position: 7,
                                     status: "published")
  page.print_content_flag = true
  page.title = I18n.t("custom.pages.contact_us.title")
  page.save!
end
