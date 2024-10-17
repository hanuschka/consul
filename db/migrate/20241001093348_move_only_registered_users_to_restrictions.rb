class MoveOnlyRegisteredUsersToRestrictions < ActiveRecord::Migration[6.1]
  def up
    ProjektPhase::FormularPhase.reset_column_information

    ProjektPhase::FormularPhase.all.find_each do |phase|
      if phase.settings.find_by(key: "feature.general.only_registered_users")&.value.present?
        phase.update!(user_status: "registered")
      else
        phase.update!(user_status: "guest")
      end
    end
  end

  def down
  end
end
