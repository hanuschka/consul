# The staff-side half of the check: the contributions of the further projekts
# the phase has selected, searched separately from the phase's own so that the
# citizen-facing find stays exactly what it was.
class SimilarContributions::FindForAdditionalProjekts < ApplicationService
  MATCH_LIMIT = 3
  USAGE_FEATURE = "similar_contributions.find_for_additional_projekts".freeze

  def initialize(resource, projekt_phase: nil)
    @resource = resource
    @projekt_phase = projekt_phase || SimilarContributions::Scopes.projekt_phase_of(resource)
  end

  # No selection means no second search and no AI call -- the phase behaves
  # exactly as it did before the setting existed.
  def call
    return [] if projekt_phase.blank?
    return [] if additional_projekts.empty?

    SimilarContributions::Find.call(
      resource,
      relation: SimilarContributions::Scopes.projekts_relation(resource, additional_projekts),
      limit: MATCH_LIMIT,
      feature: USAGE_FEATURE,
      projekt_phase: projekt_phase
    )
  end

  private

    attr_reader :resource, :projekt_phase

    def additional_projekts
      @additional_projekts ||= projekt_phase.published_similar_search_projekts.to_a
    end
end
