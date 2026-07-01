class Adm::MasterportalCollectionsListComponent < ApplicationComponent
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def render?
    collections.any?
  end

  def collections
    @collections ||= @projekt_phase.masterportal_collections.ordered
  end

  def projekt_phase
    @projekt_phase
  end
end
