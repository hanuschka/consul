class AddGuestParticipationAllowedToProjektPhase < ActiveRecord::Migration[6.1]
  def change
    unless column_exists? :projekt_phases, :guest_participation_allowed
      add_column :projekt_phases, :guest_participation_allowed, :boolean, default: false
    end
  end
end
