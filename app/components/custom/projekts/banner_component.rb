class Projekts::BannerComponent < ApplicationComponent
  def initialize(custom_page:)
    @custom_page = custom_page
    @projekt = custom_page.projekt
  end

  def show_embedded_controlls?
    @show_embedded_controlls ||= embedded_and_frame_access_code_valid?(@projekt)
  end
end
