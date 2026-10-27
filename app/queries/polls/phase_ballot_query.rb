class Polls::PhaseBallotQuery < ApplicationQuery
  # The one ballot a voting phase puts in front of citizens, or nothing. A voting
  # phase is meant to hold exactly one poll and `polls` is a has_many with nothing
  # enforcing it, so which of several is *the* ballot has to be decided somewhere —
  # and it cannot be decided by id.
  #
  # ProjektPhase::VotingPhase#poll answers the lowest id, which is the poll the
  # phase created with itself. On a phase that has since been given another that is
  # the empty scaffold rather than the ballot: there are phases carrying a
  # question-less unpublished poll from their creation beside a published one with
  # a hundred votes on it, and the scaffold is the one with the lower id.
  #
  # Published is the flag that separates them, because it is the one an admin sets
  # to put a ballot in front of citizens. Several published polls is not something
  # to pick between — that is a phase whose real question is "which of these", and
  # the projekt page asks it better than any caller here could.
  #
  # A validation forbidding the second poll is not the answer either: phases with
  # two, four and ten of them exist and are answered, so the rule would make their
  # polls unsavable and break projekt copying for them. What is fixable is which
  # poll callers reach for.
  def self.for(projekt_phase)
    new(projekt_phase: projekt_phase).call
  end

  # The same question for many phases at once, as {projekt_phase_id => poll}. One
  # query for the whole set, and a phase with none or several is simply absent.
  def self.by_phase(projekt_phase_ids)
    ::Poll
      .where(projekt_phase_id: projekt_phase_ids)
      .published
      .group_by(&:projekt_phase_id)
      .filter_map { |projekt_phase_id, polls| [projekt_phase_id, polls.first] if polls.one? }
      .to_h
  end

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def call
    return if !@projekt_phase.is_a?(ProjektPhase::VotingPhase)

    polls = ::Poll.where(projekt_phase_id: @projekt_phase.id).published.limit(2).to_a

    return if polls.size != 1

    polls.first
  end
end
