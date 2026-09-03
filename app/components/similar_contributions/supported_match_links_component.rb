class SimilarContributions::SupportedMatchLinksComponent < ApplicationComponent
  include SimilarContributionsSupporting

  # Supporting a match ends the flow, so its link replaces the surface's own
  # actions. One link per supportable match, hidden until the JS that watches
  # the refreshed vote markup reveals the one that was supported.
  attr_reader :matches, :surface

  def initialize(matches, surface:)
    @matches = Array(matches)
    @surface = surface
  end

  def link_class
    "button similar-contributions-#{surface}--supported-link " \
      "js-similar-contributions-supported-link"
  end

  def votes_container_prefix
    surface
  end
end
