# The projekts an admin may add to a phase's similarity check: every published
# participation projekt except the phase's own. Ordered newest first, because a
# city repeating a procedure every year is looking for the previous rounds.
class SimilarContributions::SelectableProjektsQuery < ApplicationQuery
  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    Projekt
      .regular
      .where.not(id: projekt_phase.projekt_id)
      .reorder(created_at: :desc)
  end

  private

    attr_reader :projekt_phase
end
