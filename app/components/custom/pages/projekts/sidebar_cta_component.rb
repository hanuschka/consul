class Pages::Projekts::SidebarCtaComponent < ApplicationComponent
  def initialize(projekt_phase = nil)
    @projekt_phase = projekt_phase
  end

  def render?
    @projekt_phase&.sidebar_cta_kind.present?
  end
end
