module FaviconHelper
  # The favicon uploaded to its image slot, or the bundled favicon.ico.
  def site_favicon_link_tag
    favicon = SiteCustomization::Image.by_name("favicon")&.persisted_image

    if favicon
      favicon_link_tag polymorphic_path(favicon), type: favicon.content_type
    else
      favicon_link_tag "favicon.ico"
    end
  end
end
