class Projekts::ContentStartSectionComponent < ApplicationComponent
  def initialize(projekt)
    @projekt = projekt
  end

  def render?
    @projekt.present?
  end
end
