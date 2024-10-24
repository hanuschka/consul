class TransferTranslatedFieldsFromPollsToProjektVotingPhases < ActiveRecord::Migration[6.1]
  def change
    ProjektPhase::VotingPhase.all.find_each do |voting_phase|
      next unless voting_phase.polls.any?

      poll = voting_phase.polls.first

      poll.translations.each do |translation|
        voting_phase.translations.each do |voting_phase_translation|
          voting_phase_translation.update(
            description: translation.summary || translation.description,
          )
        end
      end
    end
  end
end
