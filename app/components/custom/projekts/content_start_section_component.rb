class Projekts::ContentStartSectionComponent < ApplicationComponent
  def initialize(projekt)
    @projekt = projekt
  end

  def render?
    @projekt.present?
  end

  def ai_disabled?
    !Ai::Settings.ai_available?
  end
end
