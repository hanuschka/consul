class Projekts::BannerComponent < ApplicationComponent
  def initialize(custom_page:, compact: false)
    @custom_page = custom_page
    @projekt = custom_page.projekt
    @compact = compact
  end

  def show_embedded_controlls?
    return false if @compact

    @show_embedded_controlls ||= show_admin_controls_for_projekt?(@projekt)
  end

  def banner_wrapper_class
    classes = ["custom-page--banner-wrapper"]
    classes << "-compact" if @compact
    classes.join(" ")
  end
end
