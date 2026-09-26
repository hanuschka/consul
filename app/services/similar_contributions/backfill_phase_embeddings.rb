class SimilarContributions::BackfillPhaseEmbeddings < ApplicationService
  BATCH_SIZE = 96

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  # Yields how many of each batch needed a new vector, so a caller can report
  # progress on a phase with thousands of contributions.
  def call(&progress)
    relation.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      progress&.call(SimilarContributions::Embed.call(batch))
    end
  end

  private

    attr_reader :projekt_phase

    # The subject of a check is any contribution a citizen could be shown, so
    # the candidate scopes decide what is worth a vector.
    def relation
      sample = sample_resource
      return ::Proposal.none if sample.blank?

      SimilarContributions::Scopes
        .phase_relation(sample, projekt_phase)
        .except(:includes)
    end

    def sample_resource
      case projekt_phase
      when ProjektPhase::ProposalPhase then ::Proposal.new
      when ProjektPhase::BudgetPhase then ::Budget::Investment.new
      end
    end
end
