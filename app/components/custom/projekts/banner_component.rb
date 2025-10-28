class Projekts::BannerComponent < ApplicationComponent
  def initialize(custom_page:)
    @custom_page = custom_page
    @projekt = custom_page.projekt
  end

  def show_embedded_controlls?
    @show_embedded_controlls ||= show_admin_controls_for_projekt?(@projekt)
  end
end
