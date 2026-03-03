class Navigation::ProposalBrowseNavigationComponent < ApplicationComponent
  def initialize(resources:, projekt_phase:, current_order: nil)
    @resources = resources
    @projekt_phase = projekt_phase
    @current_order = current_order
  end
end
