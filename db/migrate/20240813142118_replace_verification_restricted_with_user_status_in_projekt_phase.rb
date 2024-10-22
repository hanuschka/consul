class ReplaceVerificationRestrictedWithUserStatusInProjektPhase < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        transaction do
          add_column :projekt_phases, :user_status, :integer, default: 1

          ProjektPhase.reset_column_information

          ProjektPhase.all.find_each do |phase|
            status = phase.guest_participation_allowed? ? 0 : phase.verification_restricted ? 2 : 1
            phase.update!(user_status: status)
          end

          remove_column :projekt_phases, :verification_restricted if column_exists?(:projekt_phases, :verification_restricted)
          remove_column :projekt_phases, :guest_participation_allowed if column_exists?(:projekt_phases, :guest_participation_allowed)
        end
      end

      dir.down do
        transaction do
          add_column :projekt_phases, :verification_restricted, :boolean, default: false
          add_column :projekt_phases, :guest_participation_allowed, :boolean, default: false

          ProjektPhase.reset_column_information

          ProjektPhase.all.find_each do |phase|
            phase.update!(verification_restricted: phase.user_status == 2, guest_participation_allowed: phase.user_status == 0)
          end

          remove_column :projekt_phases, :user_status if column_exists?(:projekt_phases, :user_status)
        end
      end
    end
  end
end
