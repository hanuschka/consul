# Selecting further projekts after a phase has been running leaves every
# contribution already published without a cross-projekt match, because those
# are recorded once at publish. This is the manual catch-up for exactly that,
# and it is manual because it costs one AI ranking per contribution.
class SimilarContributions::RecheckAdditionalProjekts < ApplicationService
  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  # The phase carries where the run stands, so the page can show it and the
  # button can refuse a second run on top of the first. A failure is recorded
  # and then re-raised: it belongs in delayed_jobs.last_error, where it is
  # retried and visible.
  def call
    return finish if projekt_phase.published_similar_search_projekts.empty?

    contributions.find_each do |contribution|
      next if already_referenced_ids.include?(contribution.id)

      record(contribution)
    end

    finish
  rescue StandardError => e
    projekt_phase.update(similar_search_recheck_status: :failed)
    Rails.logger.error(
      "[SimilarContributions] Additional-projekt re-check failed for phase " \
      "##{projekt_phase.id}: #{e.message}"
    )

    raise
  end

  private

    attr_reader :projekt_phase

    def finish
      projekt_phase.update!(
        similar_search_recheck_status: :completed,
        similar_search_recheck_finished_at: Time.current
      )
    end

    def contributions
      @contributions ||= SimilarContributions::PhaseContributionsQuery.call(projekt_phase)
    end

    def record(contribution)
      matches = SimilarContributions::FindForAdditionalProjekts.call(
        contribution, projekt_phase: projekt_phase
      )

      SimilarContributions::RecordReferences.call(contribution, matches)
    end

    # A contribution whose set already names a foreign match has been through
    # this, so it is left alone -- two queries for the whole phase rather than a
    # pair per contribution, and no second ranking to pay for.
    def already_referenced_ids
      @already_referenced_ids ||=
        begin
          memberships = SimilarContributionMembership.where(
            contribution_type: contributions.klass.base_class.name,
            contribution_id: contributions.select(:id)
          )

          referenced_group_ids = SimilarContributionReference
            .where(similar_contribution_group_id: memberships.select(:similar_contribution_group_id))
            .distinct
            .pluck(:similar_contribution_group_id)

          memberships
            .where(similar_contribution_group_id: referenced_group_ids)
            .pluck(:contribution_id)
            .to_set
        end
    end
end
