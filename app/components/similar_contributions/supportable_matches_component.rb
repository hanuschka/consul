class SimilarContributions::SupportableMatchesComponent < ApplicationComponent
  include SimilarContributionsSupporting

  # The list of matches on the two citizen surfaces -- the modal the check
  # opens and the decision block on the form -- which offer supporting a match
  # instead of publishing. The surface names which of the two is rendering, so
  # both can stand in the document without their vote container ids colliding.
  attr_reader :matches, :variant, :surface

  def initialize(matches, variant:, surface:)
    @matches = Array(matches)
    @variant = variant
    @surface = surface
  end

  def votes_container_prefix
    surface
  end
end
