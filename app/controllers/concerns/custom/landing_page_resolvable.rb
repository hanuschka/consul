module LandingPageResolvable
  extend ActiveSupport::Concern

  private

  def resolve_landing_page_for_projekt(projekt)
    return if projekt.blank?

    landing_page = projekt.landing_page
    return if landing_page.blank?

    @landing_page = landing_page
    set_landing_page_topbar_ui_variables(landing_page)
  end

  def resolve_landing_page_for_page(custom_page)
    return if custom_page.blank?

    if custom_page.landing?
      set_landing_page_topbar_ui_variables(custom_page)
    elsif custom_page.projekt.present?
      resolve_landing_page_for_projekt(custom_page.projekt)
    end
  end

  def set_landing_page_topbar_ui_variables(landing_page)
    @ui_show_projekts_overview = landing_page.landing_show_projekts_overview
    @ui_hide_topbar_links = landing_page.landing_hide_all_top_nav_links

    if landing_page.landing_site_logo_for_transparent_background.attached?
      @ui_site_logo_transparent_background = url_for(landing_page.landing_site_logo_for_transparent_background)
    end

    if landing_page.landing_site_logo_for_white_background.attached?
      @ui_site_logo_white_background = url_for(landing_page.landing_site_logo_for_white_background)
    end

    if landing_page.landing_site_logo_follow_to_landing_page
      @ui_site_homepage_path = landing_page.url
    end

    @ui_landing_page = landing_page
  end
end
